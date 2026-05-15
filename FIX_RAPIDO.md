# 🚨 FIX RÁPIDO - Error de Plataforma Docker

## El Problema
Tus servicios en ECS están fallando con:
```
CannotPullContainerError: Image Manifest does not contain descriptor matching platform 'linux/amd64'
```

## La Causa
Las imágenes Docker fueron construidas en Mac (ARM64) pero AWS Fargate necesita linux/amd64.

## La Solución (3 minutos)

### 1️⃣ Ejecuta el script de fix:
```bash
cd online-sales-system
chmod +x rebuild-and-push.sh
./rebuild-and-push.sh
```

Esto:
- ✅ Reconstruye las 3 imágenes con la plataforma correcta
- ✅ Las sube a ECR
- ✅ Fuerza un nuevo deployment en ECS

### 2️⃣ Verifica que funcionó:
```bash
chmod +x verify-deployment.sh
./verify-deployment.sh
```

Deberías ver:
```
✓✓✓ TODO OPERATIVO ✓✓✓
```

### 3️⃣ Reemplaza los Dockerfiles (opcional pero recomendado):
```bash
mv backend-fastapi/Dockerfile.fixed backend-fastapi/Dockerfile
mv frontend-angular/Dockerfile.fixed frontend-angular/Dockerfile
mv payment-service/Dockerfile.fixed payment-service/Dockerfile
```

## ⏱️ Tiempo Estimado
- Script rebuild: 5-10 minutos
- Deployment ECS: 3-5 minutos
- **Total: ~15 minutos**

## 📋 Antes de Ejecutar
Asegúrate de tener:
- [x] AWS CLI configurado (`aws configure`)
- [x] Docker corriendo
- [x] Permisos ECR y ECS

## ❓ Si Algo Falla
Lee el documento completo: `SOLUCION_ERROR_PLATAFORMA.md`

---
**Pro tip**: Si usas Mac con Apple Silicon, siempre construye con `--platform linux/amd64` para desplegar a Fargate.
