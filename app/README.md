# M300 Task Manager

Kleine 3-Schicht-Demo-App für dein K3s-Cluster: Frontend (Nginx + Vanilla JS),
Backend (FastAPI), Datenbank (PostgreSQL).

```
Browser → Frontend (Nginx, NodePort 30200)
              │  /api/* wird intern weitergeleitet
              ▼
          Backend (FastAPI, Service :8000)
              │
              ▼
          Postgres (Service :5432, PVC für Persistenz)
```

## 1. Images bauen und pushen

Auf dem K3s Master oder einer Maschine mit Docker/Registry-Zugriff:

```bash
cd backend
docker build -t CHANGE_ME/m300-task-backend:latest .
docker push CHANGE_ME/m300-task-backend:latest

cd ../frontend
docker build -t CHANGE_ME/m300-task-frontend:latest .
docker push CHANGE_ME/m300-task-frontend:latest
```

Ersetze `CHANGE_ME` durch deine Registry (z.B. `ghcr.io/gabrieldig` oder Docker Hub Username)
und passe dieselbe Referenz in `k8s/04-backend.yaml` und `k8s/05-frontend.yaml` an.

Falls du keine eigene Registry willst: Images stattdessen direkt auf jedem
K3s-Node lokal bauen und `imagePullPolicy: Never` in den Deployments setzen.

## 2. Deployen

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-postgres-secret.yaml
kubectl apply -f k8s/02-postgres-pvc.yaml
kubectl apply -f k8s/03-postgres.yaml
kubectl apply -f k8s/04-backend.yaml
kubectl apply -f k8s/05-frontend.yaml
```

Oder alles auf einmal: `kubectl apply -f k8s/`

## 3. Security Group anpassen

Die App läuft auf NodePort **30200**, analog zu Grafana (30080), Prometheus (30090)
und Headlamp (30100). Damit du von aussen zugreifen kannst, braucht die
`ansible_sg` in deinem Terraform-Netzwerk-Setup noch eine zusätzliche Ingress-Regel:

```hcl
ingress {
  description = "Task Manager NodePort"
  from_port   = 30200
  to_port     = 30200
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

Das kannst du direkt in `network.tf` bei den anderen NodePort-Regeln der
`ansible_sg` ergänzen.

## 4. Prüfen

```bash
kubectl get pods -n taskapp
kubectl get svc -n taskapp
```

Dann im Browser: `http://<node-ip>:30200`

## 5. Lokal testen (ohne Cluster)

```bash
docker network create taskapp-net

docker run -d --name postgres --network taskapp-net \
  -e POSTGRES_DB=tasksdb -e POSTGRES_USER=tasksuser -e POSTGRES_PASSWORD=changeme \
  postgres:16-alpine

docker build -t task-backend ./backend
docker run -d --name backend --network taskapp-net -p 8000:8000 \
  -e DB_HOST=postgres -e DB_NAME=tasksdb -e DB_USER=tasksuser -e DB_PASSWORD=changeme \
  task-backend

# Frontend proxied auf "backend" als Hostname - für rein lokalen Test
# im nginx.conf "backend:8000" ggf. anpassen oder Frontend direkt via
# `python -m http.server` aus dem frontend/-Ordner servieren und
# API_BASE in app.js auf http://localhost:8000/api setzen.
```

## Nächste Schritte (optional)

- Health-/Readiness-Checks sind schon drin (`/api/health`), passt gut zu deinem
  bestehenden Prometheus/Grafana-Setup, falls du die App später überwachen willst.
- Ingress statt NodePort, falls du später einen richtigen Domainnamen willst.
- CI/CD: Images automatisch bauen und pushen lassen, statt manuell.
