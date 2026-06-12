# ==========================================
# SECURITY GROUPS (FIREWALL-REGELN)
# ==========================================

# Ansible Controller: SSH von aussen erreichbar
resource "aws_security_group" "ansible_sg" {
  name        = "ansible-controller-sg"
  description = "SSH Zugriff von aussen auf den Ansible Controller"
  vpc_id      = aws_vpc.modul300_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Im Lab ok, produktiv eigene IP eintragen
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Grafana NodePort"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # oder deine IP: ["x.x.x.x/32"]
  }

  ingress {
    description = "Prometheus NodePort"
    from_port   = 30090
    to_port     = 30090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Headlamp Dashboard"
    from_port   = 30100
    to_port     = 30100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ansible-controller-sg" }
}

# K3s Cluster: SSH nur vom Ansible Controller
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-cluster-sg"
  description = "K3s Traffic und SSH vom Ansible Controller"
  vpc_id      = aws_vpc.modul300_vpc.id

  # SSH nur vom Ansible Controller
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ansible_sg.id]
  }

  # K3s API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Kubelet Kommunikation zwischen Master und Worker
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Flannel VXLAN (k3s internes Pod-Netzwerk)
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "k3s-cluster-sg" }
}

# Backup Manager: SSH nur vom Ansible Controller
resource "aws_security_group" "backup_sg" {
  name        = "backup-manager-sg"
  description = "SSH vom Ansible Controller"
  vpc_id      = aws_vpc.modul300_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ansible_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "backup-manager-sg" }
}
