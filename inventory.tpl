[ansible_controller]
${ansible_controller_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k3s_master]
${k3s_master_ip} ansible_user=ansible ansible_ssh_private_key_file=/home/ansible/.ssh/ansible_key.pem

[k3s_workers]
%{ for ip in k3s_worker_ips ~}
${ip} ansible_user=ansible ansible_ssh_private_key_file=/home/ansible/.ssh/ansible_key.pem
%{ endfor ~}

[backup]
${backup_manager_ip} ansible_user=ansible ansible_ssh_private_key_file=/home/ansible/.ssh/ansible_key.pem

[k3s:children]
k3s_master
k3s_workers
