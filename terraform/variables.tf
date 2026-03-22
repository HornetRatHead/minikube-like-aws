# terraform/variables.tf

# --- БАЗОВІ НАЛАШТУВАННЯ ІНФРАСТРУКТУРИ ---

variable "region" {
  description = "AWS region (наприклад, eu-central-1)"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# --- Секрети та Доступи ---

variable "postgres_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "minio_access_key" {
  description = "Access key for MinIO or SeaweedFS S3"
  type        = string
}

variable "minio_secret_key" {
  description = "Secret key for MinIO or SeaweedFS S3"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "Токен для доступу до приватного репозиторію GitHub"
  type        = string
  sensitive   = true
}

# --- НАЛАШТУВАННЯ КЛАСТЕРА (Для StockWise) ---

variable "cluster_name" {
  description = "Name of the EKS or Minikube cluster"
  type        = string
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
