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