# Modul 300 – Plattformübergreifende Dienste in ein Netzwerk integrieren
 
 Anleitungsartikel -> [Bedienungsanleitung](./Tutorial.md)
Automatisierter Aufbau einer AWS-Cloud-Infrastruktur mit Terraform (Provisionierung)
und Ansible (Konfiguration): ein K3s-Kubernetes-Cluster hinter einem Bastion Host,
mit Monitoring-Stack und einer selbst entwickelten 3-Schicht-Applikation (Task Manager).
 
## Architektur-Übersicht
 
| Komponente | Technologie | Beschreibung / Rolle im Projekt |
| :--- | :--- | :--- |
| **Infrastruktur** | AWS (EC2, VPC, S3) | Cloud-Plattform für die Bereitstellung der virtuellen Server und des Netzwerks. |
| **Provisionierung** | Terraform | Infrastructure as Code (IaC). Definiert und baut VPC, Subnetze, Sicherheitsgruppen und EC2-Instanzen vollautomatisch. |
| **Konfiguration** | Ansible | Agentenlose Konfigurations-Automatisierung. Installiert K3s auf allen Nodes, deployt den Monitoring-Stack und die Applikation. |
| **Container-Orchestrierung** | K3s (Kubernetes) | Leichtgewichtige Kubernetes-Distribution für ressourcenschonende Umgebungen. |
| **Applikation** | Task Manager (FastAPI + Nginx/Vanilla JS + PostgreSQL) | Eigene 3-Schicht-Demo-App, läuft als Deployment auf dem K3s-Cluster. |
| **Monitoring** | kube-prometheus-stack, Headlamp (Helm) | Cluster- und Node-Metriken via Grafana/Prometheus, Kubernetes-Dashboard via Headlamp. |
| **Öffentlicher Zugriff** | Nginx Reverse Proxy (auf dem Bastion Host) | Leitet Grafana, Prometheus, Headlamp und die Task-App vom Bastion Host auf die privaten NodePorts im Cluster weiter. |
| **Datensicherung** | AWS S3 + EBS | Bucket und dedizierte Backup-Manager-Instanz sind provisioniert; die eigentliche Backup-Automatisierung ist **noch offen** (siehe unten). |
 
## Komponenten-Beschreibung
 
### 1. Management Node (Bastion Host)
* **Bastion Host:** einzige Instanz mit öffentlicher IP, Gateway zum restlichen (privaten) Netzwerk.
* **Ansible Controller:** von hier aus wird das Playbook ausgeführt.
* **Nginx Reverse Proxy:** läuft direkt auf dem Bastion Host und leitet die Ports `30080` (Grafana), `30090` (Prometheus), `30100` (Headlamp) und `30200` (Task Manager) auf den privaten K3s-Master weiter. Dadurch braucht nur der Bastion Host eine öffentliche IP – der Cluster selbst bleibt komplett isoliert.
### 2. K3s Cluster
* **1x K3s Master (Control Plane):** verwaltet den Cluster-Zustand, stellt die Kubernetes-API bereit.
* **2x K3s Worker:** hier laufen die Pods der Applikation.
### 3. Task Manager Applikation
Eigene 3-Schicht-App im Namespace `taskapp`, deployt via Kubernetes-Manifeste:
* **Frontend:** statisches Vanilla-JS/HTML, ausgeliefert über Nginx, exponiert via NodePort `30200`.
* **Backend:** FastAPI mit CRUD-Endpoints (`/api/tasks`) und Health-Check (`/api/health`).
* **Datenbank:** PostgreSQL mit persistentem Volume (PVC), überlebt Pod-Neustarts.
### 4. Monitoring
Via Helm auf dem K3s-Master installiert:
* **kube-prometheus-stack:** Grafana (NodePort `30080`) und Prometheus (NodePort `30090`) für Cluster- und Node-Metriken.
* **Headlamp:** Kubernetes-Dashboard (NodePort `30100`) mit eigenem ServiceAccount und Login-Token.
### 5. Backup-Infrastruktur (provisioniert, Automatisierung offen)
Terraform legt bereits Folgendes an:
* Eine dedizierte **Backup-Manager**-Instanz in einem eigenen privaten Subnetz.
* Ein persistentes **EBS-Volume**, das `terraform destroy` übersteht (`skip_destroy = true`).
* Ein **S3-Bucket** mit Versionierung für externe Backups.
**Offen:** Es gibt aktuell noch kein Ansible-Task/Cronjob, der tatsächlich Daten (z.B. K3s-State oder die Postgres-DB) auf den Backup-Manager bzw. nach S3 sichert. Die Infrastruktur dafür steht, die Automatisierung selbst ist ein möglicher nächster Schritt.
```mermaid
graph TB
    %% Definition der Subgraphs (Logische Gruppierung)
    subgraph Management ["Management Ebene (AWS EC2)"]
        MgmtServer["Management Server<br><i>(Ansible Controller / Bastion)</i>"]
    end

    subgraph K3sCluster ["K3s Kubernetes Cluster (AWS EC2)"]
        MasterNode["K3s Master Node<br><i>(Control Plane / API)</i>"]
        
        subgraph Workers ["Worker Nodes"]
            Worker1["K3s Worker Node 1<br><i>(App Pods)</i>"]
            Worker2["K3s Worker Node 2<br><i>(App Pods)</i>"]
        end
    end

    subgraph Storage ["Externer Speicher (AWS S3)"]
        S3Bucket[("AWS S3 Bucket<br><i>(Sicheres Backup-Repository)</i>")]
    end

    %% Definition der Verbindungen und Datenflüsse
    %% Ansible Steuerung (SSH)
    MgmtServer -- "1. Automatisiert via SSH (Port 22)" --> MasterNode
    MgmtServer -- "1. Automatisiert via SSH (Port 22)" --> Worker1
    MgmtServer -- "1. Automatisiert via SSH (Port 22)" --> Worker2

    %% Cluster interne Kommunikation
    MasterNode -- "2. Orchestrierung & Kubelet" --> Worker1
    MasterNode -- "2. Orchestrierung & Kubelet" --> Worker2

    %% Backup Datenfluss
    MasterNode -- "3. Verschlüsseltes etcd/DB-Backup" --> S3Bucket
    Workers -.->|Opt. Anwendungs-Backups| S3Bucket

%% Styling / Verschönerung des Diagramms und der Kästen
    style MgmtServer fill:#f9f,stroke:#333,stroke-width:2px,rx:10,ry:10
    style MasterNode fill:#bbf,stroke:#333,stroke-width:2px,rx:10,ry:10
    style Worker1 fill:#ddf,stroke:#333,stroke-width:1px,rx:10,ry:10
    style Worker2 fill:#ddf,stroke:#333,stroke-width:1px,rx:10,ry:10
    style S3Bucket fill:#ffe3b3,stroke:#ff9900,stroke-width:2px
    
    %% DEFINIERTE VERFÄRBUNGEN DER GROSSEN KÄSTEN
    classDef managementStyle fill:#fff0f5,stroke:#999,stroke-width:1px,stroke-dasharray: 5 5,color:#333;
    classDef k3sClusterStyle fill:#e6f3ff,stroke:#999,stroke-width:1px,stroke-dasharray: 5 5,color:#333;
    classDef workerNodesStyle fill:#bcd2ee,stroke:#999,stroke-width:1px,stroke-dasharray: 5 5,color:#333;
    classDef storageStyle fill:#ffefd5,stroke:#999,stroke-width:1px,stroke-dasharray: 5 5,color:#333;

    class Management managementStyle
    class K3sCluster k3sClusterStyle
    class Workers workerNodesStyle
    class Storage storageStyle
```