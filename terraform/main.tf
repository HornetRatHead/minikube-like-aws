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
  kubernetes = {
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

# --- 3. ЕМУЛЯЦІЯ RDS (PostgreSQL через Bitnami (Chainguard)) ---
resource "helm_release" "postgresql" {
  name       = "rds-emulation"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.ns["application"].metadata[0].name
  version    = "18.5.5" # Фіксована версія для стабільності

  timeout = 600      
  wait    = false    
  atomic  = false    

  set = [
    { name  = "readReplicas.replicaCount", value = "0" },
    { name  = "primary.resources.requests.cpu", value = var.postgres_resources["cpu_req"] },
    { name  = "primary.resources.requests.memory", value = var.postgres_resources["mem_req"] },
    { name  = "primary.resources.limits.cpu", value = var.postgres_resources["cpu_lim"] },
    { name  = "primary.resources.limits.memory", value = var.postgres_resources["mem_lim"] },
 
    { name  = "auth.database", value = "mlflow_db" },
    { name  = "auth.postgresPassword", value = var.postgres_password },
    { name  = "primary.persistence.enabled", value = "true" },
    { name  = "primary.persistence.size", value = "8Gi" }
  ]  
}

# --- 4. ЕМУЛЯЦІЯ S3 (MinIO через Seaweedfs) ---
  resource "helm_release" "seaweedfs" {
  name       = "s3-seaweedfs"
  repository = "https://seaweedfs.github.io/seaweedfs/helm"
  chart      = "seaweedfs"
  namespace  = kubernetes_namespace.ns["application"].metadata[0].name
  force_update = true

  timeout = 600      
  wait    = false    
  atomic  = false    

  set = [
    { name  = "image.repository", value = "chrislusf/seaweedfs" },
    { name  = "image.tag", value = "4.17" },
    { name  = "image.pullPolicy", value = "IfNotPresent" },

    { name  = "global.security.allowInsecureImages", value = "true"},

    { name  = "master.containerImage", value = "chrislusf/seaweedfs:4.17" },
    { name  = "volume.containerImage", value = "chrislusf/seaweedfs:4.17" },
    { name  = "filer.containerImage", value = "chrislusf/seaweedfs:4.17" },
    { name  = "s3.containerImage", value = "chrislusf/seaweedfs:4.17" },

    { name = "s3.resources.requests.cpu", value = "100m" },
    { name = "s3.resources.requests.memory", value = "128Mi" },
    { name = "s3.resources.limits.cpu", value = "200m" },
    { name = "s3.resources.limits.memory", value = "256Mi" },

    { name = "master.enabled", value = "true" },
    { name = "volume.enabled", value = "true" },

    { name  = "s3.enabled", value = "true" },
    { name  = "filer.enabled", value = "true" },
    { name  = "filer.database.type", value = "leveldb"},

    { name  = "s3.accessKey", value = var.minio_access_key },    
    { name  = "s3.secretKey", value = var.minio_secret_key }, 

    { name  = "master.replicas", value = var.minio_resources["replicas"] },
    { name  = "filer.replicas", value = var.minio_resources["replicas"] },

    { name = "master.data.type", value = "persistentVolumeClaim" },
    { name = "master.data.size", value = "1Gi" },
    { name = "master.data.storageClass", value = "standard" },
    { name = "master.resources.requests.cpu", value = "100m" },
    { name = "master.resources.requests.memory", value = "128Mi" },
    { name = "master.resources.limits.cpu", value = "200m" },
    { name = "master.resources.limits.memory", value = "256Mi" },

    { name = "filer.data.type", value = "persistentVolumeClaim" },
    { name = "filer.data.size", value = "2Gi" },
    { name = "filer.data.storageClass", value = "standard" },

    { name  = "volume.dataDirs[0].name", value = "data" },
    { name  = "volume.dataDirs[0].type", value = "persistentVolumeClaim" },
    { name  = "volume.dataDirs[0].size", value = "10Gi" },
    { name  = "volume.dataDirs[0].storageClass", value = "standard" },
    { name = "volume.resources.requests.cpu", value = "100m" },
    { name = "volume.resources.requests.memory", value = "256Mi" },
    { name = "volume.resources.limits.cpu", value = "500m" },
    { name = "volume.resources.limits.memory", value = "512Mi" },

    { name  = "filer.resources.requests.cpu", value = var.minio_resources["cpu_req"] },
    { name  = "filer.resources.requests.memory", value = var.minio_resources["mem_req"] },
    { name  = "filer.resources.limits.cpu", value = var.minio_resources["cpu_lim"] },
    { name  = "filer.resources.limits.memory", value = var.minio_resources["mem_lim"] },
    { name = "filer.resources.requests.cpu", value = "100m" },
    { name = "filer.resources.requests.memory", value = "256Mi" },
    { name = "filer.resources.limits.cpu", value = "500m" },
    { name = "filer.resources.limits.memory", value = "512Mi" }
  ] 
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
  MLFLOW_S3_ENDPOINT_URL = "http://s3-seaweedfs-filer.application.svc.cluster.local:8333"
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

  set = [
    { name  = "server.extraArgs", value = "{--insecure}" }
  ]
}

# --- MLflow ---
resource "helm_release" "mlflow" {
  name       = "mlflow"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "mlflow"
  version    = "5.1.17"
  namespace  = kubernetes_namespace.ns["application"].metadata[0].name

  timeout    = 600
  wait       = false

  set = [
    { name = "image.registry",               value = "docker.io" },
    { name = "image.repository",             value = "bitnamilegacy/mlflow" },
    { name = "image.tag",                    value = "3.3.2-debian-12-r0" },
    { name = "image.pullPolicy",             value = "Never" },

    { name = "postgresql.enabled",           value = "false" },
    { name = "minio.enabled",                value = "false" },
    { name = "auth.enabled",                 value = "false" },
    { name = "volumePermissions.enabled",    value = "false" },
    { name = "rbac.create",                  value = "false" },

    { name = "waitContainer.image.registry",   value = "docker.io" },
    { name = "waitContainer.image.repository", value = "bitnamilegacy/os-shell" },
    { name = "waitContainer.image.tag",        value = "12-debian-12-r51" },
    { name = "waitContainer.image.pullPolicy", value = "Never" },

    { name = "externalDatabase.waitContainer.image.repository", value = "bitnamilegacy/os-shell" },
    { name = "externalDatabase.waitContainer.image.tag",        value = "12-debian-12-r51" },
    { name = "externalDatabase.waitContainer.image.pullPolicy", value = "Never" },

    { name = "externalS3.waitContainer.image.repository", value = "bitnamilegacy/os-shell" },
    { name = "externalS3.waitContainer.tag",              value = "12-debian-12-r51" },
    { name = "externalS3.waitContainer.pullPolicy",       value = "Never" },

    { name = "externalDatabase.host",        value = "rds-emulation-postgresql" },
    { name = "externalDatabase.port",        value = "5432" },
    { name = "externalDatabase.user",        value = "postgres" },
    { name = "externalDatabase.password",    value = var.postgres_password },
    { name = "externalDatabase.database",    value = "mlflow_db" },

    { name = "backendStore.externalDatabase.host",     value = "rds-emulation-postgresql" },
    { name = "backendStore.externalDatabase.port",     value = "5432" },
    { name = "backendStore.externalDatabase.user",     value = "postgres" },
    { name = "backendStore.externalDatabase.password", value = var.postgres_password },
    { name = "backendStore.externalDatabase.database", value = "mlflow_db" },
    { name = "backendStore.databaseMigration",         value = "true" },

    { name = "externalS3.host",           value = "s3-seaweedfs-s3" },
    { name = "externalS3.port",           value = "8333" },
    { name = "externalS3.bucket",         value = "mlflow-artifacts" },
    { name = "externalS3.accessKey",      value = var.minio_access_key },
    { name = "externalS3.secretKey",      value = var.minio_secret_key },

    { name = "global.security.allowInsecureImages", value = "true" },
    { name = "resources.requests.cpu",               value = "100m" },
    { name = "resources.requests.memory",            value = "256Mi" },
    { name = "resources.limits.cpu",                 value = "500m" },
    { name = "resources.limits.memory",              value = "512Mi" }
  ]
}
# --- GLUE ---

