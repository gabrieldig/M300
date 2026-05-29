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
