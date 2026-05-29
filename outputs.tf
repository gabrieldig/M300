# ==========================================
# OUTPUTS
# ==========================================

output "ansible_controller_public_ip" {
  description = "Öffentliche IP des Ansible Controllers (SSH-Einstiegspunkt)"
  value       = aws_instance.ansible_controller.public_ip
}

output "k3s_master_private_ip" {
  description = "Private IP des K3s Masters"
  value       = aws_instance.k3s_master.private_ip
}

output "k3s_worker_private_ips" {
  description = "Private IPs der K3s Worker Nodes"
  value       = aws_instance.k3s_worker[*].private_ip
}

output "backup_manager_private_ip" {
  description = "Private IP des Backup Managers"
  value       = aws_instance.backup_manager.private_ip
}

output "ssh_command" {
  description = "SSH Befehl zum Ansible Controller"
  value       = "ssh -i ~/.ssh/m300.pem ubuntu@${aws_instance.ansible_controller.public_ip}"
}
output "ansible_command" {
  description = "Ansible Befehl zum Starten"
  value       = "ansible-playbook -i /home/ansible/M300/ansible/inventory.ini /home/ansible/M300/ansible/playbook.yml"
}