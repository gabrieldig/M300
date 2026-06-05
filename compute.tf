# ==========================================
# COMPUTE INSTANZEN (EC2)
# ==========================================

variable "key_name" {
  default     = "m300"
  description = "Name des SSH Key Pairs für manuellen Zugriff (m300.pem)"
}

# Neuestes Ubuntu 22.04 LTS AMI automatisch holen
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

# user_data: ansible-User + Public Key auf allen privaten Nodes
locals {
  ansible_user_data = <<-EOF
    #!/bin/bash
    useradd -m -s /bin/bash ansible
    mkdir -p /home/ansible/.ssh
    chmod 700 /home/ansible/.ssh
    echo "${tls_private_key.ansible_key.public_key_openssh}" >> /home/ansible/.ssh/authorized_keys
    chmod 600 /home/ansible/.ssh/authorized_keys
    chown -R ansible:ansible /home/ansible/.ssh
    echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
    chmod 440 /etc/sudoers.d/ansible
  EOF
}

# Ansible Controller (public subnet, SSH-Einstiegspunkt)
resource "aws_instance" "ansible_controller" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public_sub.id
  vpc_security_group_ids      = [aws_security_group.ansible_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y ansible python3-pip

    useradd -m -s /bin/bash ansible
    mkdir -p /home/ansible/.ssh
    chmod 700 /home/ansible/.ssh

    cat > /home/ansible/.ssh/ansible_key.pem << PRIVATEKEY
    ${tls_private_key.ansible_key.private_key_pem}
    PRIVATEKEY

    chmod 600 /home/ansible/.ssh/ansible_key.pem
    chown -R ansible:ansible /home/ansible/.ssh
    echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
    chmod 440 /etc/sudoers.d/ansible
  EOF

  tags = { Name = "ansible-controller" }
}

# K3s Master
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_compute_sub.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = var.key_name
  user_data              = local.ansible_user_data

  iam_instance_profile   = "LabInstanceProfile"
  
  tags = { Name = "k3s-master" }
}

# K3s Worker Nodes (count = 2 erstellt worker-1 und worker-2)
resource "aws_instance" "k3s_worker" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_compute_sub.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = var.key_name
  user_data              = local.ansible_user_data

  tags = { Name = "k3s-worker-${count.index + 1}" }
}

# Backup Manager
resource "aws_instance" "backup_manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_storage_sub.id
  vpc_security_group_ids = [aws_security_group.backup_sg.id]
  key_name               = var.key_name
  user_data              = local.ansible_user_data

  iam_instance_profile   = "LabInstanceProfile"

  tags = { Name = "backup-manager" }
}
