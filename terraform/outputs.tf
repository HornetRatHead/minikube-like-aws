# terraform/outputs.tf

output "postgresql_host" {
  value       = "rds-emulation-postgresql.application.svc.cluster.local"
  description = "Внутрішня адреса бази даних (аналог RDS Endpoint)"
}

output "minio_s3_endpoint" {
  value       = "http://s3-emulation-minio.application.svc.cluster.local:9000"
  description = "Внутрішня адреса S3 (аналог S3 Service Endpoint)"
}

output "argocd_admin_password_command" {
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  description = "Команда для отримання пароля ArgoCD"
}
