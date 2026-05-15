from pydantic import BaseModel


class ProductBase(BaseModel):
    name: str
    price: float


class ProductCreate(ProductBase):
    stock: int = 0


class Product(ProductBase):
    id: int
    stock: int

    model_config = {"from_attributes": True}
