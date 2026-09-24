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

    # Chargily Pay (sandbox) — pay-and-collect, escrow held in our Payment model per Phase 2 spec
    chargily_api_key: str = "test_6f2d8e2a-1234-4a5b-9c9d-test_sandbox_key"
    chargily_api_secret: str = "test_sandbox_secret_do_not_use_in_prod"
    chargily_api_url: str = "https://pay.chargily.net/api/v2"
    chargily_webhook_secret: str = "test_webhook_secret"
    chargily_sandbox: bool = True

    # Auto-release after completed with no dispute/release
    auto_release_days: int = 7

    # Observability
    sentry_dsn: str | None = None
    log_level: str = "INFO"
    prometheus_enabled: bool = True

    # Admin UI password login (dashboard only — API data still needs the JWT).
    # Plain password is NEVER stored: set ADMIN_PASSWORD_HASH to a bcrypt hash
    # (generate: python -c "from app.core.security import hash_password;
    #  print(hash_password('...'))"). Empty hash disables the endpoint.
    admin_username: str = "admin"
    admin_password_hash: str = ""


settings = Settings()
