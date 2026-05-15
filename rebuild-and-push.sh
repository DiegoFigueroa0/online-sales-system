#!/bin/bash

# Script para reconstruir imágenes Docker con la plataforma correcta para AWS Fargate
# Uso: ./rebuild-and-push.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables - EDITA ESTAS SEGÚN TU CONFIGURACIÓN
AWS_REGION="us-east-1"  # Cambia según tu región
AWS_ACCOUNT_ID="788356290964"  # Tu ID de cuenta AWS
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Servicios a construir
SERVICES=("backend-api" "frontend-app" "payment-api")
DIRECTORIES=("backend-fastapi" "frontend-angular" "payment-service")

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Reconstrucción de Imágenes Docker para ECS     ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""

# Verificar que Docker está corriendo
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker no está corriendo${NC}"
    exit 1
fi

# Login a ECR
echo -e "${YELLOW}[1/5] Autenticando con AWS ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
echo -e "${GREEN}✓ Autenticación exitosa${NC}"
echo ""

# Habilitar buildx si no está activo
echo -e "${YELLOW}[2/5] Configurando Docker Buildx...${NC}"
docker buildx create --use --name multiarch-builder --driver docker-container 2>/dev/null || docker buildx use multiarch-builder
echo -e "${GREEN}✓ Buildx configurado${NC}"
echo ""

# Construir y subir cada servicio
echo -e "${YELLOW}[3/5] Construyendo imágenes Docker...${NC}"
for i in "${!SERVICES[@]}"; do
    SERVICE=${SERVICES[$i]}
    DIRECTORY=${DIRECTORIES[$i]}
    IMAGE_URI="${ECR_REGISTRY}/${SERVICE}:latest"
    
    echo ""
    echo -e "${YELLOW}→ Construyendo ${SERVICE}...${NC}"
    
    cd ${DIRECTORY}
    
    # Construir para linux/amd64 (requerido por Fargate)
    docker buildx build \
        --platform linux/amd64 \
        --tag ${IMAGE_URI} \
        --push \
        .
    
    echo -e "${GREEN}✓ ${SERVICE} construido y subido exitosamente${NC}"
    
    cd ..
done

echo ""
echo -e "${YELLOW}[4/5] Verificando imágenes en ECR...${NC}"
for SERVICE in "${SERVICES[@]}"; do
    echo "  → ${SERVICE}:"
    aws ecr describe-images \
        --repository-name ${SERVICE} \
        --region ${AWS_REGION} \
        --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
        --output table 2>/dev/null || echo "    (No se pudo verificar - el repositorio existe?)"
done

echo ""
echo -e "${YELLOW}[5/5] Forzando nuevo deployment en ECS...${NC}"

# Forzar actualización de servicios ECS
CLUSTER_NAME="online-sales-cluster"  # Cambia si tu cluster tiene otro nombre
ECS_SERVICES=("backend-service" "frontend-service" "payment-service")

for ECS_SERVICE in "${ECS_SERVICES[@]}"; do
    echo "  → Actualizando ${ECS_SERVICE}..."
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${ECS_SERVICE} \
        --force-new-deployment \
        --region ${AWS_REGION} \
        > /dev/null 2>&1 && echo -e "${GREEN}    ✓ ${ECS_SERVICE} actualizado${NC}" || echo -e "${RED}    ✗ Error actualizando ${ECS_SERVICE}${NC}"
done

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}          ¡PROCESO COMPLETADO!                   ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Las imágenes han sido reconstruidas para linux/amd64 y subidas a ECR."
echo "Los servicios ECS han sido forzados a un nuevo deployment."
echo ""
echo "Monitorea el estado en la consola de ECS:"
echo "https://${AWS_REGION}.console.aws.amazon.com/ecs/v2/clusters/${CLUSTER_NAME}/services"
echo ""
