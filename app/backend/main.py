import os
import time
from contextlib import asynccontextmanager
from typing import Optional

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "tasksdb")
DB_USER = os.getenv("DB_USER", "tasksuser")
DB_PASSWORD = os.getenv("DB_PASSWORD", "changeme")


def get_conn():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        cursor_factory=RealDictCursor,
    )


def wait_for_db(max_retries: int = 30, delay: float = 2.0):
    """Retries DB connection on startup since Postgres pod might not be ready yet."""
    for attempt in range(1, max_retries + 1):
        try:
            conn = get_conn()
            conn.close()
            return
        except psycopg2.OperationalError as exc:
            print(f"[startup] DB not ready (attempt {attempt}/{max_retries}): {exc}")
            time.sleep(delay)
    raise RuntimeError("Database never became ready")


def init_db():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS tasks (
                    id SERIAL PRIMARY KEY,
                    title TEXT NOT NULL,
                    done BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                """
            )
        conn.commit()
    finally:
        conn.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    wait_for_db()
    init_db()
    yield


app = FastAPI(title="M300 Task Manager API", lifespan=lifespan)

# Erlaubt Zugriff vom Frontend (NodePort/andere Origin im Cluster)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class TaskCreate(BaseModel):
    title: str


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    done: Optional[bool] = None


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.get("/api/tasks")
def list_tasks():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title, done, created_at FROM tasks ORDER BY id DESC;")
            return cur.fetchall()
    finally:
        conn.close()


@app.post("/api/tasks", status_code=201)
def create_task(task: TaskCreate):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO tasks (title) VALUES (%s) RETURNING id, title, done, created_at;",
                (task.title,),
            )
            row = cur.fetchone()
        conn.commit()
        return row
    finally:
        conn.close()


@app.patch("/api/tasks/{task_id}")
def update_task(task_id: int, task: TaskUpdate):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM tasks WHERE id = %s;", (task_id,))
            if cur.fetchone() is None:
                raise HTTPException(status_code=404, detail="Task nicht gefunden")

            fields = []
            values = []
            if task.title is not None:
                fields.append("title = %s")
                values.append(task.title)
            if task.done is not None:
                fields.append("done = %s")
                values.append(task.done)

            if fields:
                values.append(task_id)
                cur.execute(
                    f"UPDATE tasks SET {', '.join(fields)} WHERE id = %s "
                    f"RETURNING id, title, done, created_at;",
                    values,
                )
                row = cur.fetchone()
                conn.commit()
                return row

            cur.execute("SELECT id, title, done, created_at FROM tasks WHERE id = %s;", (task_id,))
            return cur.fetchone()
    finally:
        conn.close()


@app.delete("/api/tasks/{task_id}", status_code=204)
def delete_task(task_id: int):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM tasks WHERE id = %s;", (task_id,))
        conn.commit()
    finally:
        conn.close()
