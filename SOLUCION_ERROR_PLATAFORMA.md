# 🔧 Solución al Error de Plataforma Docker en AWS ECS Fargate

## 📋 Resumen del Problema

**Error**: `CannotPullContainerError: Image Manifest does not contain descriptor matching platform 'linux/amd64'`

**Causa**: Las imágenes Docker fueron construidas en Mac con Apple Silicon (ARM64) pero AWS Fargate requiere imágenes `linux/amd64`.

**Servicios Afectados**:
- ✗ backend-service (100+ errores)
- ✗ frontend-service (9 errores)
- ✗ payment-service (18 errores)

---

## 🚀 SOLUCIÓN RÁPIDA (Método Recomendado)

### Opción 1: Script Automático

1. **Ejecuta el script de reconstrucción:**
   ```bash
   cd online-sales-system
   chmod +x rebuild-and-push.sh
   ./rebuild-and-push.sh
   ```

2. **Monitorea el deployment:**
   - Ve a la consola de ECS
   - Observa que los servicios empiezan a desplegar tareas exitosamente
   - Espera 3-5 minutos para que todos los servicios estén "RUNNING"

---

## 🛠️ SOLUCIÓN MANUAL (Paso a Paso)

### Paso 1: Configurar Docker Buildx

```bash
# Crear builder multi-plataforma
docker buildx create --use --name multiarch-builder --driver docker-container

# Verificar
docker buildx ls
```

### Paso 2: Login a AWS ECR

```bash
# Reemplaza con tu región
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="788356290964"

aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
```

### Paso 3: Reconstruir Imágenes

#### Backend Service:
```bash
cd backend-fastapi

docker buildx build \
    --platform linux/amd64 \
    --tag 788356290964.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest \
    --push \
    .

cd ..
```

#### Frontend Service:
```bash
cd frontend-angular

docker buildx build \
    --platform linux/amd64 \
    --tag 788356290964.dkr.ecr.us-east-1.amazonaws.com/frontend-app:latest \
    --push \
    .

cd ..
```

#### Payment Service:
```bash
cd payment-service

docker buildx build \
    --platform linux/amd64 \
    --tag 788356290964.dkr.ecr.us-east-1.amazonaws.com/payment-api:latest \
    --push \
    .

cd ..
```

### Paso 4: Forzar Nuevo Deployment en ECS

```bash
CLUSTER="online-sales-cluster"
REGION="us-east-1"

# Backend
aws ecs update-service \
    --cluster ${CLUSTER} \
    --service backend-service \
    --force-new-deployment \
    --region ${REGION}

# Frontend
aws ecs update-service \
    --cluster ${CLUSTER} \
    --service frontend-service \
    --force-new-deployment \
    --region ${REGION}

# Payment
aws ecs update-service \
    --cluster ${CLUSTER} \
    --service payment-service \
    --force-new-deployment \
    --region ${REGION}
```

---

## 📝 MEJORAS IMPLEMENTADAS

### 1. Dockerfiles Mejorados

He creado versiones `.fixed` de todos los Dockerfiles con:

✅ **Plataforma explícita**: `FROM --platform=linux/amd64`
✅ **Healthchecks**: Para mejor monitoreo en ECS
✅ **Optimización de layers**: Mejor caching de dependencias

**Para usarlos:**
```bash
# Reemplaza los Dockerfiles originales
mv backend-fastapi/Dockerfile.fixed backend-fastapi/Dockerfile
mv frontend-angular/Dockerfile.fixed frontend-angular/Dockerfile
mv payment-service/Dockerfile.fixed payment-service/Dockerfile
```

### 2. GitHub Actions Workflow

Si quieres automatizar el CI/CD, crea `.github/workflows/deploy.yml`:

```yaml
name: Deploy to ECS

on:
  push:
    branches: [ main ]

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 788356290964.dkr.ecr.us-east-1.amazonaws.com

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push backend
      run: |
        docker buildx build --platform linux/amd64 \
          -t ${{ env.ECR_REGISTRY }}/backend-api:latest \
          --push backend-fastapi/
    
    - name: Build and push frontend
      run: |
        docker buildx build --platform linux/amd64 \
          -t ${{ env.ECR_REGISTRY }}/frontend-app:latest \
          --push frontend-angular/
    
    - name: Build and push payment
      run: |
        docker buildx build --platform linux/amd64 \
          -t ${{ env.ECR_REGISTRY }}/payment-api:latest \
          --push payment-service/
    
    - name: Force new deployment
      run: |
        aws ecs update-service --cluster online-sales-cluster \
          --service backend-service --force-new-deployment
        aws ecs update-service --cluster online-sales-cluster \
          --service frontend-service --force-new-deployment
        aws ecs update-service --cluster online-sales-cluster \
          --service payment-service --force-new-deployment
```

---

## ✅ VERIFICACIÓN

### 1. Verificar Imágenes en ECR

```bash
aws ecr describe-images \
    --repository-name backend-api \
    --region us-east-1 \
    --query 'sort_by(imageDetails,& imagePushedAt)[-1]'
```

Deberías ver:
- `imageTags`: ["latest"]
- `imagePushedAt`: (fecha reciente)
- `imageSizeInBytes`: (tamaño de la imagen)

### 2. Verificar Servicios ECS

```bash
aws ecs describe-services \
    --cluster online-sales-cluster \
    --services backend-service frontend-service payment-service \
    --region us-east-1 \
    --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
    --output table
```

Deberías ver:
```
-----------------------------------------------------
|              DescribeServices                     |
+-------------------+--------+----------+----------+
|  backend-service  | ACTIVE |    1     |    1     |
|  frontend-service | ACTIVE |    1     |    1     |
|  payment-service  | ACTIVE |    1     |    1     |
+-------------------+--------+----------+----------+
```

### 3. Verificar Eventos (sin errores)

Ir a la consola AWS ECS y verificar que:
- ✅ No hay más errores de "CannotPullContainerError"
- ✅ Ves eventos: "has started 1 tasks: task XXX"
- ✅ Estado del servicio: "steady state"

---

## 🎯 PREVENCIÓN FUTURA

### Para Desarrollo Local:

Siempre construye con la plataforma correcta:

```bash
# Opción 1: Usar buildx
docker buildx build --platform linux/amd64 -t mi-imagen .

# Opción 2: Especificar en docker build
docker build --platform linux/amd64 -t mi-imagen .
```

### Para CI/CD:

- Usa runners de GitHub Actions (son linux/amd64 por defecto)
- Especifica `--platform linux/amd64` en todos los builds
- Habilita Docker buildx en el pipeline

---

## 📊 RESULTADO ESPERADO

Después de ejecutar la solución:

**ANTES:**
```
backend-service:  ERROR - CannotPullContainerError (100 eventos)
frontend-service: ERROR - CannotPullContainerError (9 eventos)
payment-service:  ERROR - CannotPullContainerError (18 eventos)
```

**DESPUÉS:**
```
backend-service:  ✓ RUNNING (1/1 tareas)
frontend-service: ✓ RUNNING (1/1 tareas)
payment-service:  ✓ RUNNING (1/1 tareas)
```

---

## 🆘 TROUBLESHOOTING

### Error: "buildx not found"

```bash
# Instalar buildx
docker buildx install
```

### Error: "unauthorized: authentication required"

```bash
# Re-autenticar con ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    788356290964.dkr.ecr.us-east-1.amazonaws.com
```

### Error: "repository does not exist"

Verifica que los repositorios en ECR existan:
```bash
aws ecr describe-repositories --region us-east-1
```

### Las tareas siguen fallando después del fix

1. Verifica los logs de CloudWatch:
   ```bash
   aws logs tail /ecs/backend-service --follow
   ```

2. Revisa las definiciones de tareas para asegurar que apuntan a :latest

3. Espera 5-10 minutos para que ECS drene las tareas viejas

---

## 📚 RECURSOS

- [AWS Fargate Platform Versions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform_versions.html)
- [Docker Multi-platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [Amazon ECR User Guide](https://docs.aws.amazon.com/ecr/)

---

**Autor**: Solución generada por Claude
**Fecha**: Mayo 2026
**Versión**: 1.0
