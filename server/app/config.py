from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    google_client_id: str
    google_client_secret: str
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 30

    class Config:
        env_file = ".env"

settings = Settings()
