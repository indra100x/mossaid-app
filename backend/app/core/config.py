from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "Mossaid API"
    app_env: str = "local"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://mossaid:mossaid@localhost:5432/mossaid"
    # Sync URL for Alembic
    database_url_sync: str = "postgresql+psycopg2://mossaid:mossaid@localhost:5432/mossaid"
    redis_url: str = "redis://localhost:6379/0"
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 15
    jwt_refresh_token_expire_days: int = 30


settings = Settings()
