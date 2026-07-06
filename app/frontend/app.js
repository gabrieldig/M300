// Backend-URL: gleicher Host, anderer Port/Pfad je nach Deployment.
// Im Cluster läuft das Frontend hinter einem Nginx, der /api an den Backend-Service weiterleitet.
const API_BASE = "/api";

const form = document.getElementById("task-form");
const input = document.getElementById("task-input");
const list = document.getElementById("task-list");
const status = document.getElementById("status");

async function loadTasks() {
  status.textContent = "Lade Aufgaben...";
  try {
    const res = await fetch(`${API_BASE}/tasks`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const tasks = await res.json();
    renderTasks(tasks);
    status.textContent = `${tasks.length} Aufgabe(n) geladen.`;
  } catch (err) {
    status.textContent = `Fehler beim Laden: ${err.message}`;
  }
}

function renderTasks(tasks) {
  list.innerHTML = "";
  for (const task of tasks) {
    const li = document.createElement("li");
    li.className = "task-item" + (task.done ? " done" : "");

    const span = document.createElement("span");
    span.textContent = task.title;
    span.addEventListener("click", () => toggleTask(task));

    const delBtn = document.createElement("button");
    delBtn.textContent = "Löschen";
    delBtn.addEventListener("click", () => deleteTask(task.id));

    li.appendChild(span);
    li.appendChild(delBtn);
    list.appendChild(li);
  }
}

async function toggleTask(task) {
  try {
    await fetch(`${API_BASE}/tasks/${task.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ done: !task.done }),
    });
    loadTasks();
  } catch (err) {
    status.textContent = `Fehler beim Aktualisieren: ${err.message}`;
  }
}

async function deleteTask(id) {
  try {
    await fetch(`${API_BASE}/tasks/${id}`, { method: "DELETE" });
    loadTasks();
  } catch (err) {
    status.textContent = `Fehler beim Löschen: ${err.message}`;
  }
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const title = input.value.trim();
  if (!title) return;

  try {
    await fetch(`${API_BASE}/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title }),
    });
    input.value = "";
    loadTasks();
  } catch (err) {
    status.textContent = `Fehler beim Hinzufügen: ${err.message}`;
  }
});

loadTasks();
