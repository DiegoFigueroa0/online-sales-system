import mercadopago
from app.config.settings import settings


def _get_payment_method(card_number: str) -> str:
    first = card_number[0] if card_number else "4"
    if first == "4":
        return "visa"
    if first == "5":
        return "master"
    if first == "3":
        return "amex"
    return "visa"


def process_payment(
    card_number: str,
    cardholder_name: str,
    expiry_month: int,
    expiry_year: int,
    security_code: str,
    amount: float,
) -> dict:
    if not card_number:
        return {"status": "error", "message": "Número de tarjeta inválido"}

    if not settings.mercadopago_access_token:
        return {"status": "error", "message": "Servicio de pago no configurado"}

    try:
        sdk = mercadopago.SDK(settings.mercadopago_access_token)

        # Normalize year (accept both 2-digit and 4-digit)
        year = expiry_year if expiry_year > 2000 else 2000 + expiry_year

        # Create card token
        token_response = sdk.card_token().create({
            "card_number": card_number,
            "expiration_month": expiry_month,
            "expiration_year": year,
            "security_code": security_code,
            "cardholder": {
                "name": cardholder_name or "APRO",
                "identification": {
                    "type": "DNI",
                    "number": "00000000",
                },
            },
        })

        if token_response["status"] != 201:
            return {
                "status": "error",
                "message": f"Error al tokenizar tarjeta: {token_response.get('response', {})}",
            }

        token = token_response["response"]["id"]

        payment_data = {
            "transaction_amount": float(amount) if amount > 0 else 100.0,
            "token": token,
            "description": "Compra en NEXSTORE",
            "installments": 1,
            "payment_method_id": _get_payment_method(card_number),
            "payer": {
                "email": "test_user_123@testuser.com",
            },
        }

        payment_response = sdk.payment().create(payment_data)
        payment = payment_response["response"]

        status = payment.get("status", "error")
        return {
            "status": "approved" if status == "approved" else "rejected",
            "transaction_id": str(payment.get("id", "")),
            "amount": payment.get("transaction_amount", amount),
            "message": payment.get("status_detail", ""),
        }

    except Exception as e:
        return {"status": "error", "message": f"Error procesando pago: {str(e)}"}
