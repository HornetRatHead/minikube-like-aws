#!/bin/bash

# Зупинка при помилці
set -e

# Налаштування кольорів
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Починаємо розгортання проекту minikube-like-aws...${NC}"

# # 1. Перевірка залежностей
check_tool() {
    command -v $1 >/dev/null 2>&1 || { echo -e "❌ $1 не встановлено. Перервано."; exit 1; }
}

check_tool minikube
check_tool terraform
check_tool kubectl

# 2. Запуск Minikube
echo -e "\n${BLUE}📦 Крок 1: Запуск Minikube (4 CPU, 6GB RAM)...${NC}"
if minikube status | grep -q "Running"; then
    echo "Minikube вже працює."
else
    minikube start --cpus=4 --memory=6144 --driver=docker
fi

echo -e "${BLUE}🍦 Крок 2: Ввімкнення Ingress...${NC}"
minikube addons enable ingress

# 3. Terraform Apply
echo -e "\n${BLUE}🏗️ Крок 3: Розгортання інфраструктури через Terraform...${NC}"
cd "$(dirname "$0")/../terraform"
terraform init
terraform apply -auto-approve

# 4. Створення баз даних для MLflow
echo -e "\n${BLUE}🗄️ Крок 4: Налаштування баз даних для MLflow...${NC}"

# Дістаємо пароль і перевіряємо, чи він не порожній
DB_PASS=$(terraform output -raw postgres_password 2>/dev/null)

if [ -z "$DB_PASS" ]; then
    echo -e "${RED}Помилка: Не вдалося отримати пароль з Terraform!${NC}"
    exit 1
fi

echo -e "${YELLOW}Створюємо бази даних (автоматично)...${NC}"

# Використовуємо -i без -t, щоб уникнути проблем з терміналом
kubectl exec -i rds-emulation-postgresql-0 -n application -- \
    sh -c "PGPASSWORD='$DB_PASS' psql -U postgres -c 'CREATE DATABASE mlflow_db;' && PGPASSWORD='$DB_PASS' psql -U postgres -c 'CREATE DATABASE mlflow_auth;'" \
    || echo "Бази вже існують або виникла помилка підключення."

# 5. Health Check (Перевірка готовності MLflow)
echo -e "\n${BLUE}🧪 Крок 5: Перевірка готовності сервісів StockWise...${NC}"
echo -e "${YELLOW}Очікуємо, поки компоненти MLflow стануть 'Ready'...${NC}"
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/instance=mlflow" -n application --timeout=180s

echo -e "\n${GREEN}==========================================================${NC}"
echo -e "${GREEN}✅ ІНФРАСТРУКТУРА РОЗГОРНУТА ТА ГОТОВА ДО РОБОТИ!${NC}"
echo -e "${GREEN}==========================================================${NC}"

# 6. Витягуємо дані та паролі
POSTGRES_HOST=$(terraform output -raw postgresql_host)
MINIO_ENDPOINT=$(terraform output -raw minio_s3_endpoint)

echo -e "${BLUE}📍 Реквізити підключення:${NC}"
echo -e "DB (RDS-like):  $POSTGRES_HOST"
echo -e "S3 (MinIO):      $MINIO_ENDPOINT"

pkill -f "port-forward" || true
sleep 1

# ArgoCD
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "\n${GREEN}--- ArgoCD ---${NC}"
echo -e "Username: admin"
echo -e "Password: $ARGOCD_PASS"
echo -e "Команда:  kubectl port-forward svc/argocd-server -n argocd 8443:443"
kubectl port-forward svc/argocd-server -n argocd 8443:443 > /dev/null 2>&1 &

# MLflow
MLFLOW_USER=$(kubectl get secret -n application mlflow-tracking -o jsonpath="{.data.admin-user}" | base64 -d)
MLFLOW_PASS=$(kubectl get secret -n application mlflow-tracking -o jsonpath="{.data.admin-password}" | base64 -d)
echo -e "\n${GREEN}--- MLflow (StockWise) ---${NC}"
echo -e "Username: $MLFLOW_USER"
echo -e "Password: $MLFLOW_PASS"
echo -e "Команда:  kubectl port-forward svc/mlflow-tracking -n application 8080:80"
kubectl port-forward svc/mlflow-tracking -n application 8080:80 > /dev/null 2>&1 &

echo -e "${GREEN}🚀 Порти вже прокинуті! Перевіряй браузер.${NC}"

echo -e "\n${BLUE}👉 Тепер Minikube_like_AWS готовий до експериментів!${NC}"
