from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.cart import CartItem
from app.models.product import Product
from app.schemas.cart_schema import CartItemAdd

router = APIRouter(prefix="/cart", tags=["Cart"])


@router.get("/")
def get_cart(db: Session = Depends(get_db)):
    items = db.query(CartItem).all()
    result = []
    for item in items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if product:
            result.append({
                "id": item.id,
                "product_id": item.product_id,
                "product_name": product.name,
                "price": product.price,
                "quantity": item.quantity,
            })
    return result


@router.post("/add")
def add_to_cart(data: CartItemAdd, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == data.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    existing = db.query(CartItem).filter(CartItem.product_id == data.product_id).first()
    if existing:
        existing.quantity += data.quantity
    else:
        db.add(CartItem(product_id=data.product_id, quantity=data.quantity))
    db.commit()
    return {"message": "Producto agregado al carrito"}


@router.delete("/remove/{item_id}")
def remove_from_cart(item_id: int, db: Session = Depends(get_db)):
    item = db.query(CartItem).filter(CartItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item no encontrado")
    db.delete(item)
    db.commit()
    return {"message": "Producto eliminado"}


@router.delete("/clear")
def clear_cart(db: Session = Depends(get_db)):
    db.query(CartItem).delete()
    db.commit()
    return {"message": "Carrito vaciado"}
