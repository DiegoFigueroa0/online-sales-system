from fastapi import APIRouter
from pydantic import BaseModel
from app.services.mercadopago_service import process_payment

router = APIRouter(tags=["Payment"])


class PaymentRequest(BaseModel):
    card_number: str
    amount: float = 0.0


@router.post("/pay")
def pay(data: PaymentRequest):
    return process_payment(data.card_number, data.amount)
