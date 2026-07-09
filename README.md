# Modul 300 Plattformübergreifende Dienste in ein Netzwerk integrieren

## Projektplan


## Architektur-Übersicht

| Komponente |Technologie |Beschreibung / Rolle im Projekt |
| :---        | :---        | :---                         |
| **Infrastruktur** | AWS (EC2, VPC, S3) | Cloud-Plattform für die Bereitstellung der virtuellen Server und des Netzwerks. |
| **Provisionierung** | Terraform | Infrastructure as Code (IaC). Definiert und baut das VPC, die Subnetze, Sicherheitsgruppen und EC2-Instanzen vollautomatisch. |
| **Konfiguration** | Ansible | Agentenlose Konfigurations-Automatisierung. Installiert und konfiguriert K3s, Docker und Absicherungen auf den Nodes. |
| **Container-Orchestrierung** | K3s (Kubernetes) | Eine hochgradig optimierte, leichtgewichtige Kubernetes-Distribution. Perfekt für ressourcenschonende Umgebungen. |
| **Lokaler Paket-Spiegel** | `debmirror` (Docker) | Ein "Run-and-Die"-Container, der eine ultra-schlanke, lokale Kopie von Ubuntu-Sicherheitsupdates vorhält (ohne GUIs/Spiele). |
| **Datensicherung** | AWS S3 | Externer, hochverfügbarer Objektspeicher für die automatisierten K3s- und Anwendungs-Backups. |

## Komponenten-Beschreibung

### 1. Management Node
Der Managementserver nimmt übernimmt die Managementrolle und dient als zentrale Steueranlage:
* **Bastion Host:** Er ist die einzige Instanz mit einer öffentlichen IP-Adresse und fungiert als sicheres Gateway zum K3s-Cluster, da sie in einem Isolierten Netzt liegen, ohne Öffentlichen Zugang.
* **Ansible Controller:** Von hier aus werden die Ansible-Playbooks gestartet.

### 2. K3s Cluster
* **1x K3s Master (Control Plane):** Verwaltet den Cluster-Zustand, steuert die Pods und stellt die Kubernetes-API bereit.
* **2x K3s Worker:** Hier laufen die eigentlichen containerisierten Anwendungen (Pods). Sie erhalten ihre Befehle und Netzwerk-Routing direkt vom Master.
  
#### 3. Backup-Strategie via AWS S3
Die Datensicherheit wird komplett von den Compute-Ressourcen entkoppelt:
* K3s triggert automatisierte Snapshots des Cluster-Zustands.
* Diese Backups werden verschlüsselt direkt in einen **AWS S3 Bucket** geladen.
* **Vorteil (Disaster Recovery):** Sollte das gesamte Cluster irreparabel beschädigt werden, kann die Infrastruktur mittels Terraform und Ansible innerhalb von Minuten neu aufgebaut und der Zustand aus dem S3-Bucket fehlerfrei wiederhergestellt werden.



## Kurzanleitung
Im Verzeichnis starten man das Projekt mit ``Terrafor plan`` und ``Terraform apply`` um die Infrastruktur aufzubauen.

Dannach sieht man ein output:
![alt text](image.png)

Im Output sieht man alles das man braucht, um sich mt dem Cluster zu verbinden:
- Öffentliche IP Addresse der Bastion Host
- Private IP Adressen der Master und Worker Nodes
- SSH Command um direkt auf die Master Node zuzugreifen.

Dannach muss man in den Ansible User wechseln mit ``sudo su ansible`` und von dort ins Homeverzeichnis gehen: ``cd ~``

Dort findet man das Github Repository und darin befindet sich der Ansible Ordner mit allen nötigen Scripts.

Mit ``ansible-playbook -i /home/ansible/M300/ansible/inventory.ini /home/ansible/M300/ansible/playbook.yml`` kann man das Playbook ausführen, um die K3s-Cluster zu konfigurieren.


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