# terraform/outputs.tf

# Пароль до бази даних PostgreSQL
output "postgres_password" {
  description = "The password for the PostgreSQL database"
  value     = var.postgres_password
  sensitive = true
}

# Адреси та ендпоінти
output "postgresql_host" {
  value = "rds-emulation-postgresql.application.svc.cluster.local"
}

output "minio_s3_endpoint" {
  value = "http://s3-seaweedfs-s3.application.svc.cluster.local:8333"
}

# Ключ доступу до S3 (SeaweedFS)
output "minio_access_key" {
  description = "The Access Key for SeaweedFS S3"
  value       = var.minio_access_key
}

# Секретний ключ до S3 (SeaweedFS)
output "minio_secret_key" {
  description = "The Secret Key for SeaweedFS S3"
  value       = var.minio_secret_key 
  sensitive   = true
}
