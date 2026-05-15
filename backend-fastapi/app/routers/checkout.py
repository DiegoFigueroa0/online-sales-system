from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.cart import CartItem
from app.models.product import Product
from app.services.payment_service import process_payment

router = APIRouter(prefix="/checkout", tags=["Checkout"])


class CheckoutRequest(BaseModel):
    card_number: str


@router.post("/")
def checkout(data: CheckoutRequest, db: Session = Depends(get_db)):
    cart_items = db.query(CartItem).all()
    if not cart_items:
        raise HTTPException(status_code=400, detail="El carrito está vacío")

    total = 0.0
    for item in cart_items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if product:
            total += product.price * item.quantity

    result = process_payment({"card_number": data.card_number, "amount": total})

    if result.get("status") == "approved":
        db.query(CartItem).delete()
        db.commit()

    return result
