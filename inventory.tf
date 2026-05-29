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