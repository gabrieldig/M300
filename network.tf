# ==========================================
# NETZWERK-INFRASTRUKTUR (VPC)
# ==========================================

resource "aws_vpc" "modul300_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "modul300-vpc" }
}

# Öffentliches Subnet (für Ansible Controller)
resource "aws_subnet" "public_sub" {
  vpc_id                  = aws_vpc.modul300_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "modul300-public-subnet" }
}

# Privates Subnet für das K3s-Cluster
resource "aws_subnet" "private_compute_sub" {
  vpc_id            = aws_vpc.modul300_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "modul300-private-compute" }
}

# Privates Subnet für das Backup-Management
resource "aws_subnet" "private_storage_sub" {
  vpc_id            = aws_vpc.modul300_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "modul300-private-storage" }
}

# Internet Gateway für das Public Subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.modul300_vpc.id
  tags   = { Name = "modul300-igw" }
}

# Route Table für Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.modul300_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "modul300-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_sub.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway damit private Instanzen Updates/Packages laden können
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "modul300-nat-eip" }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_sub.id
  tags          = { Name = "modul300-nat-gw" }
}

# Route Table für Private Subnets (via NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.modul300_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "modul300-private-rt" }
}

resource "aws_route_table_association" "private_compute_assoc" {
  subnet_id      = aws_subnet.private_compute_sub.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_storage_assoc" {
  subnet_id      = aws_subnet.private_storage_sub.id
  route_table_id = aws_route_table.private_rt.id
}

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

  ingress {
    description = "Task Manager Frontend NodePort"
    from_port   = 30200
    to_port     = 30200
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
y
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "K3s NodePorts (Grafana, Prometheus, Headlamp, Task-App)"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Erlaubt Traffic aus dem gesamten internen VPC
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
