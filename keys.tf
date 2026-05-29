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
