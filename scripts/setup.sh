#!/bin/bash
# scripts/setup.sh

# Налаштування кольорів для виводу
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

set -e # Зупинка при помилці

echo -e "${BLUE}🚀 Починаємо розгортання проекту minikube-like-aws...${NC}"

# 1. Перевірка залежностей
check_tool() {
    command -v $1 >/dev/null 2>&1 || { echo -e "❌ $1 не встановлено. Перервано."; exit 1; }
}

check_tool minikube
check_tool terraform
check_tool kubectl

# 2. Запуск Minikube
echo -e "${BLUE}📦 Крок 1: Запуск Minikube (4 CPU, 6GB RAM)...${NC}"
# Перевіряємо, чи він уже не запущений, щоб не гаяти час
if minikube status | grep -q "Running"; then
    echo "Minikube вже працює."
else
    minikube start --cpus=4 --memory=6144 --driver=docker
fi

echo -e "${BLUE}🔌 Крок 2: Ввімкнення Ingress...${NC}"
minikube addons enable ingress

# 3. Terraform Apply
echo -e "${BLUE}🏗️ Крок 3: Розгортання інфраструктури через Terraform...${NC}"
cd ../terraform
terraform init
terraform apply -auto-approve

# 4. Витягуємо дані з Output
echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}✅ ІНФРАСТРУКТУРА РОЗГОРНУТА УСПІШНО!${NC}"
echo -e "${GREEN}==================================================${NC}"

POSTGRES_HOST=$(terraform output -raw postgresql_host)
MINIO_ENDPOINT=$(terraform output -raw minio_s3_endpoint)

echo -e "${BLUE}📍 Реквізити для підключення:${NC}"
echo -e "DB (RDS-like):  $POSTGRES_HOST"
echo -e "S3 (MinIO):     $MINIO_ENDPOINT"

# 5. Отримання пароля ArgoCD
echo -e "\n${BLUE}🔐 Доступ до ArgoCD:${NC}"
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "Username: admin"
echo -e "Password: $ARGOCD_PASS"

echo -e "\n${BLUE}👉 Щоб зайти в ArgoCD інтерфейс, виконай:${NC}"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"

