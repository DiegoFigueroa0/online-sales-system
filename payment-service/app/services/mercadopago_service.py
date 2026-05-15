from app.config.settings import settings


def process_payment(card_number: str, amount: float) -> dict:
    if not card_number:
        return {"status": "error", "message": "Tarjeta inválida"}

    # TODO: integrar SDK real de MercadoPago cuando se configure MERCADOPAGO_ACCESS_TOKEN
    # import mercadopago
    # sdk = mercadopago.SDK(settings.mercadopago_access_token)
    # result = sdk.payment().create({...})

    return {
        "status": "approved",
        "transaction_id": f"TXN-{abs(hash(card_number)) % 1_000_000:06d}",
        "amount": amount,
    }
