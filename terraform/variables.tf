# terraform/variables.tf

# --- Секрети та Доступи ---

variable "postgres_password" {
  description = "Пароль для бази даних PostgreSQL"
  type        = string
  sensitive   = true 
}

variable "minio_access_key" {
  description = "Логін для MinIO"
  type        = string
}

variable "minio_secret_key" {
  description = "Пароль для MinIO"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "Токен для доступу до приватного репозиторію GitHub"
  type        = string
  sensitive   = true
}

# --- Конфігурація ресурсів ---

variable "postgres_resources" {
  description = "Об'єкт з лімітами та запитами для PostgreSQL"
  type        = map(string)
}

variable "minio_resources" {
  description = "Об'єкт з лімітами та запитами для MinIO"
  type        = map(string)
}
