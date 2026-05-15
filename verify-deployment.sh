#!/bin/bash

# Script de verificación del estado de ECS
# Uso: ./verify-deployment.sh

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="788356290964"
CLUSTER_NAME="online-sales-cluster"
SERVICES=("backend-service" "frontend-service" "payment-service")
REPOSITORIES=("backend-api" "frontend-app" "payment-api")

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verificación de Deployment en ECS    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Función para obtener el estado de un servicio
check_service() {
    local service=$1
    
    local result=$(aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${service} \
        --region ${AWS_REGION} \
        --query 'services[0].[status,runningCount,desiredCount,deployments[0].status]' \
        --output text 2>/dev/null)
    
    if [ -z "$result" ]; then
        echo -e "${RED}✗ No se pudo obtener información${NC}"
        return 1
    fi
    
    local status=$(echo $result | awk '{print $1}')
    local running=$(echo $result | awk '{print $2}')
    local desired=$(echo $result | awk '{print $3}')
    local deployment_status=$(echo $result | awk '{print $4}')
    
    echo "  Estado: $status"
    echo "  Tareas: ${running}/${desired} ejecutándose"
    echo "  Deployment: $deployment_status"
    
    if [ "$running" == "$desired" ] && [ "$running" != "0" ]; then
        echo -e "${GREEN}  ✓ Servicio operativo${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ Servicio aún no está estable${NC}"
        return 1
    fi
}

# Función para verificar imagen en ECR
check_ecr_image() {
    local repo=$1
    
    local result=$(aws ecr describe-images \
        --repository-name ${repo} \
        --region ${AWS_REGION} \
        --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imagePushedAt,imageSizeInBytes]' \
        --output text 2>/dev/null)
    
    if [ -z "$result" ]; then
        echo -e "${RED}  ✗ No hay imágenes${NC}"
        return 1
    fi
    
    local pushed=$(echo $result | awk '{print $1}')
    local size=$(echo $result | awk '{print $2}')
    local size_mb=$((size / 1024 / 1024))
    
    echo "  Última actualización: $pushed"
    echo "  Tamaño: ${size_mb} MB"
    
    # Verificar que la imagen sea reciente (últimas 24 horas)
    local pushed_epoch=$(date -d "$pushed" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)
    local diff=$((now_epoch - pushed_epoch))
    
    if [ $diff -lt 86400 ]; then
        echo -e "${GREEN}  ✓ Imagen actualizada recientemente${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ Imagen antigua (más de 24h)${NC}"
        return 1
    fi
}

# Función para obtener últimos eventos
check_events() {
    local service=$1
    
    echo "  Últimos 3 eventos:"
    aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${service} \
        --region ${AWS_REGION} \
        --query 'services[0].events[:3].[createdAt,message]' \
        --output text 2>/dev/null | while read -r line; do
        echo "    • $line"
    done
}

# 1. Verificar imágenes en ECR
echo -e "${YELLOW}[1/3] Verificando imágenes en ECR...${NC}"
echo ""

ecr_ok=0
for i in "${!REPOSITORIES[@]}"; do
    repo=${REPOSITORIES[$i]}
    echo -e "${BLUE}► ${repo}:${NC}"
    if check_ecr_image "$repo"; then
        ((ecr_ok++))
    fi
    echo ""
done

# 2. Verificar servicios ECS
echo -e "${YELLOW}[2/3] Verificando servicios ECS...${NC}"
echo ""

services_ok=0
for service in "${SERVICES[@]}"; do
    echo -e "${BLUE}► ${service}:${NC}"
    if check_service "$service"; then
        ((services_ok++))
    fi
    echo ""
done

# 3. Verificar eventos recientes
echo -e "${YELLOW}[3/3] Eventos recientes...${NC}"
echo ""

for service in "${SERVICES[@]}"; do
    echo -e "${BLUE}► ${service}:${NC}"
    check_events "$service"
    echo ""
done

# Resumen final
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           RESUMEN                      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

total_repos=${#REPOSITORIES[@]}
total_services=${#SERVICES[@]}

echo "Imágenes ECR: ${ecr_ok}/${total_repos} actualizadas"
echo "Servicios ECS: ${services_ok}/${total_services} operativos"
echo ""

if [ "$ecr_ok" == "$total_repos" ] && [ "$services_ok" == "$total_services" ]; then
    echo -e "${GREEN}✓✓✓ TODO OPERATIVO ✓✓✓${NC}"
    echo ""
    echo "Tu aplicación está desplegada y funcionando correctamente."
    exit 0
else
    echo -e "${YELLOW}⚠ DEPLOYMENT EN PROGRESO ⚠${NC}"
    echo ""
    echo "Algunos servicios aún están desplegándose."
    echo "Espera unos minutos y vuelve a ejecutar este script."
    echo ""
    echo "Para monitorear en tiempo real:"
    echo "  aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICES[0]} --region ${AWS_REGION}"
    exit 1
fi
