# ==========================================
# SSH KEY FÜR ANSIBLE USER (automatisch generiert)
# ==========================================

# RSA Schlüsselpaar wird von Terraform selbst generiert
resource "tls_private_key" "ansible_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Public Key bei AWS registrieren
resource "aws_key_pair" "ansible_keypair" {
  key_name   = "ansible-controller-key"
  public_key = tls_private_key.ansible_key.public_key_openssh
}

# Private Key lokal speichern (ansible/keys/ ist via .gitignore geschützt)
resource "local_file" "ansible_private_key" {
  content         = tls_private_key.ansible_key.private_key_pem
  filename        = "${path.module}/../ansible/keys/ansible_key.pem"
  file_permission = "0600"
}

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

    echo 'export ANSIBLE_CONFIG=/home/ansible/M300/ansible/ansible.cfg' >> /home/ansible/.bashrc

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

# ==========================================
# STORAGE (EBS)
# ==========================================

# Separates EBS Volume für persistente Backups (überlebt terraform destroy)
resource "aws_ebs_volume" "backup_volume" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "persistent-backup-storage" }
}

resource "aws_volume_attachment" "backup_attach" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.backup_volume.id
  instance_id  = aws_instance.backup_manager.id
  skip_destroy = true # WICHTIG: Verhindert Datenverlust beim wöchentlichen destroy/apply
}

# ==========================================
# S3 OBJECT STORAGE (Für externe Backups)
# ==========================================

resource "aws_s3_bucket" "k3s_backup_bucket" {
  bucket        = "gabrieldig-m300-k3s-backups" # MUSS weltweit eindeutig sein!
  force_destroy = false                         # Löscht den Bucket nicht, wenn noch Daten drin sind

  # Verhindert, dass der Bucket bei einem normalen "terraform destroy" gelöscht wird
  #lifecycle {
  #  prevent_destroy = true
  #}

  tags = { Name = "m300-k3s-s3-backup-storage" }
}

# Versionierung aktivieren (Schutz vor versehentlichem Überschreiben)
resource "aws_s3_bucket_versioning" "backup_versioning" {
  bucket = aws_s3_bucket.k3s_backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ==========================================
# GIT CLONE + ANSIBLE INVENTORY GENERIERUNG
# ==========================================

# Schritt 1: Repo auf den Ansible Controller klonen (Direkt ins Ansible-Home)
resource "null_resource" "git_clone" {
  triggers = {
    controller_ip = aws_instance.ansible_controller.public_ip
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/m300.pem")
    host        = aws_instance.ansible_controller.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Warten bis cloud-init (user_data) fertig ist (stellt sicher, dass der ansible-User existiert)
      "cloud-init status --wait",

      # Als root ausführen, um im Verzeichnis des ansible-Users zu arbeiten
      "sudo rm -rf /home/ansible/M300",
      "sudo git clone https://github.com/gabrieldig/M300.git /home/ansible/M300",
      "sudo chown -R ansible:ansible /home/ansible/M300"
    ]
  }
}

# Schritt 2: Inventory ins geklonte Repo schreiben
resource "null_resource" "remote_ansible_inventory" {
  depends_on = [null_resource.git_clone]

  triggers = {
    controller_ip = aws_instance.ansible_controller.public_ip
    master_ip     = aws_instance.k3s_master.private_ip
    worker_ips    = join(",", aws_instance.k3s_worker[*].private_ip)
    backup_ip     = aws_instance.backup_manager.private_ip
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/m300.pem")
    host        = aws_instance.ansible_controller.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Das Inventory über ein temporäres File als Root in den korrekten Ordner schreiben
      "cat > /tmp/inventory.tmp << 'INVEOF'",
      "${templatefile("${path.module}/inventory.tpl", {
        ansible_controller_ip = aws_instance.ansible_controller.public_ip
        k3s_master_ip         = aws_instance.k3s_master.private_ip
        k3s_worker_ips        = aws_instance.k3s_worker[*].private_ip
        backup_manager_ip     = aws_instance.backup_manager.private_ip
      })}",
      "INVEOF",

      # Verschieben und Rechte an den ansible-User übergeben
      "sudo mv /tmp/inventory.tmp /home/ansible/M300/ansible/inventory.ini",
      "sudo chown ansible:ansible /home/ansible/M300/ansible/inventory.ini",
      "echo 'Inventory erfolgreich geschrieben:' ",
      "sudo cat /home/ansible/M300/ansible/inventory.ini"
    ]
  }
}
