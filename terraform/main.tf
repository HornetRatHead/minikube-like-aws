# --- 1. ПРОВАЙДЕРИ ТА ВЕРСІЇ ---
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# --- 2. NAMESPACES (Логічна ізоляція середовищ) ---
resource "kubernetes_namespace" "ns" {
  for_each = toset(["argocd", "application", "monitoring"])
  metadata {
    name = each.key
  }
}

# 2.1. RESOURCE QUOTA (Обмеження на весь Namespace)
resource "kubernetes_resource_quota" "app_quota" {
  metadata {
    name      = "application-quota"
    namespace = kubernetes_namespace.ns["application"].metadata[0].name
  }
  spec {
    hard = {
      cpu    = "3"      # Всього не більше 3 ядер для всіх подів разом
      memory = "4Gi"    # Всього не більше 4ГБ для всіх подів разом
      pods   = "10"     # Не більше 10 подів
    }
  }
}

# --- 3. ЕМУЛЯЦІЯ RDS (PostgreSQL через Bitnami) ---
resource "helm_release" "postgresql" {
  name       = "rds-emulation"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.ns["application"].metadata[0].name
  version    = "18.0.5" # Фіксована версія для стабільності

  # Kонтроль кількості подів
  set {
    name  = "readReplicas.replicaCount"
    value = "0"
  }

  set {
    name  = "commonLabels.replicaCount" # Для Bitnami архітектури
    value = var.postgres_config["replicas"]
  }

  # Встановлення лімітів ресурсів
  # Гарантія (Requests)
  set {
    name  = "primary.resources.requests.cpu"
    value = var.postgres_resources["cpu_req"]
  }
  set {
    name  = "primary.resources.requests.memory"
    value = var.postgres_resources["mem_req"]
  }

  # Стеля (Limits)
  set {
    name  = "primary.resources.limits.cpu"
    value = var.postgres_resources["cpu_lim"]
  }
  set {
    name  = "primary.resources.limits.memory"
    value = var.postgres_resources["mem_lim"]
  }
 
  set {
    name  = "auth.database"
    value = "mlflow_db"
  }
  set {
    name  = "auth.postgresPassword"
    value = var.postgres_password
  }
  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }
  set {
    name  = "primary.persistence.size"
    value = "8Gi"
  }
}

# --- 4. ЕМУЛЯЦІЯ S3 (MinIO через Bitnami) ---
resource "helm_release" "minio" {
  name       = "s3-emulation"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "minio"
  namespace  = kubernetes_namespace.ns["application"].metadata[0].name
  version    = "17.0.21"

  # Контроль кількості подів
  set {
    name  = "replicaCount"
    value = "1"
  }

  set {
    name  = "replicaCount"
    value = var.minio_config["replicas"]
  }

  # Гарантія (Requests)
  set {
    name  = "resources.requests.cpu"
    value = var.minio_resources["cpu_req"]
  }
  set {
    name  = "resources.requests.memory"
    value = var.minio_resources["mem_req"]
  }

  # Стеля (Limits)
  set {
    name  = "resources.limits.cpu"
    value = var.minio_resources["cpu_lim"]
  }
  set {
    name  = "resources.limits.memory"
    value = var.minio_resources["mem_lim"]
  }

  set {
    name  = "auth.rootUser"
    value = var.minio_access_key
  }
  set {
    name  = "auth.rootPassword"
    value = var.minio_secret_ke
  }
  set {
    name  = "image.registry"
    value = "docker.io"  # або quay.io/bitnami
  }
  set {
    name  = "image.repository"
    value = "bitnami/minio"  # або cgr.dev/chainguard/minio
  }
  set {
    name  = "image.tag"
    value = "latest"
  }
  set {
    name  = "global.security.allowInsecureImages"
    value = "true"
  }

  # Створюємо бакети заздалегідь, як в Terraform для AWS S3
  set {
    name  = "defaultBuckets"
    value = "mlflow-artifacts"
  }
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.size"
    value = "10Gi"
  }
}

# --- 5. ЕМУЛЯЦІЯ IAM & SECRETS ---
# Створюємо секрет, який додаток підхопить як змінні оточення AWS
resource "kubernetes_secret" "mlflow_s3_creds" {
  metadata {
    name      = "mlflow-s3-creds"
    namespace = kubernetes_namespace.ns["application"].metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.minio_access_key
    AWS_SECRET_ACCESS_KEY = var.minio_secret_key
    MLFLOW_S3_ENDPOINT_URL = "http://s3-emulation-minio.application.svc.cluster.local:9000"
  }

  type = "Opaque"
}

# --- 6. ОРКЕСТРАЦІЯ (ArgoCD) ---
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.ns["argocd"].metadata[0].name
  version    = "8.5.10"

  # Налаштування для локального використання без HTTPS (якщо потрібно)
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}
