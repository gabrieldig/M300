# ==========================================
# 1. PROVIDER & BASE CONTEXT
# ==========================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Standardregion für das AWS Learner Lab
}

# ==========================================
# 2. NETZWERK-INRASTRUKTUR (VPC)
# ==========================================
resource "aws_vpc" "modul300_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "modul300-vpc" }
}

# Öffentliches Subnet (für ALB / Ingress)
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

# ==========================================
# 3. SECURITY GROUPS (FIREWALL-REGELN)
# ==========================================

# Sicherheitsgruppe für den Bastion Host (SSH von aussen)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "SSH Zugriff von aussen auf den Bastion Host"
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

  tags = { Name = "bastion-sg" }
}

# Sicherheitsgruppe für das K3s-Cluster
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-cluster-sg"
  description = "Regeln fuer K3s Traffic und SSH"
  vpc_id      = aws_vpc.modul300_vpc.id

  # SSH nur vom Bastion Host
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # K3s API Server Kommunikation
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "k3s-cluster-sg" }
}

# Sicherheitsgruppe für den Backup Manager
resource "aws_security_group" "backup_sg" {
  name        = "backup-manager-sg"
  description = "Regeln fuer den Backup Server"
  vpc_id      = aws_vpc.modul300_vpc.id

  # SSH nur vom Bastion Host
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "backup-manager-sg" }
}

# ==========================================
# 4. COMPUTE NODE DEFINITIONEN (EC2)
# ==========================================

variable "key_name" {
  default = "m300"
  description = "Name des SSH Key Pairs in AWS"
}

# Standard Ubuntu 22.04 LTS AMI holen
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# Bastion Host (öffentliches Subnet, SSH-Einstiegspunkt)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_sub.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = { Name = "bastion-host" }
}

# K3s Master Server
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_compute_sub.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = var.key_name

  tags = { Name = "k3s-master" }
}

# K3s Worker Node
resource "aws_instance" "k3s_worker" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_compute_sub.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = var.key_name

  tags = { Name = "k3s-worker-${count.index + 1}" }
}

# Backup-Management Instanz
resource "aws_instance" "backup_manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_storage_sub.id
  vpc_security_group_ids = [aws_security_group.backup_sg.id]
  key_name               = var.key_name

  tags = { Name = "backup-manager" }
}

# ==========================================
# 5. PERSISTENTES STORAGE SYSTEM (EBS)
# ==========================================

resource "aws_ebs_volume" "backup_volume" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  encrypted         = true

  tags = { Name = "persistent-backup-storage" }
}

resource "aws_volume_attachment" "backup_attach" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.backup_volume.id
  instance_id  = aws_instance.backup_manager.id
  skip_destroy = true
}

# ==========================================
# 6. OUTPUTS
# ==========================================

output "bastion_public_ip" {
  description = "Öffentliche IP des Bastion Hosts (SSH-Einstiegspunkt)"
  value       = aws_instance.bastion.public_ip
}

output "k3s_master_private_ip" {
  description = "Private IP des K3s Masters"
  value       = aws_instance.k3s_master.private_ip
}

output "k3s_worker_private_ips" {
  description = "Private IPs der K3s Worker Nodes"
  value       = aws_instance.k3s_worker[*].private_ip # Das [*] gibt alle IPs als Liste aus
}

output "backup_manager_private_ip" {
  description = "Private IP des Backup Managers"
  value       = aws_instance.backup_manager.private_ip
}
