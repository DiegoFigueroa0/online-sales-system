#!/bin/bash
set -e

echo "Reemplazando Dockerfiles con versiones mejoradas..."
echo ""

# Backend
if [ -f "backend-fastapi/Dockerfile.fixed" ]; then
    mv backend-fastapi/Dockerfile backend-fastapi/Dockerfile.old 2>/dev/null || true
    mv backend-fastapi/Dockerfile.fixed backend-fastapi/Dockerfile
    echo "✓ Backend: Dockerfile actualizado"
fi

# Frontend
if [ -f "frontend-angular/Dockerfile.fixed" ]; then
    mv frontend-angular/Dockerfile frontend-angular/Dockerfile.old 2>/dev/null || true
    mv frontend-angular/Dockerfile.fixed frontend-angular/Dockerfile
    echo "✓ Frontend: Dockerfile actualizado"
fi

# Payment
if [ -f "payment-service/Dockerfile.fixed" ]; then
    mv payment-service/Dockerfile payment-service/Dockerfile.old 2>/dev/null || true
    mv payment-service/Dockerfile.fixed payment-service/Dockerfile
    echo "✓ Payment: Dockerfile actualizado"
fi

echo ""
echo "¡Dockerfiles actualizados!"
