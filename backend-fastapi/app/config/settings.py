from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://user:password@db:5432/sales"
    secret_key: str = "change-me-in-production"
    payment_service_url: str = "http://payment-service:8001/pay"

    model_config = {"env_file": ".env"}


settings = Settings()
