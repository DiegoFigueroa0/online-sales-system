import requests
from fastapi import HTTPException
from app.config.settings import settings


def process_payment(data: dict) -> dict:
    try:
        response = requests.post(settings.payment_service_url, json=data, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"Error en servicio de pago: {e}")
