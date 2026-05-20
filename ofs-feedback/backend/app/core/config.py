from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Aplicacao
    APP_NAME: str = "OFS Feedback"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"

    # JWT
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Senhas / Lockout
    PASSWORD_MIN_LENGTH: int = 12
    PASSWORD_EXPIRATION_DAYS: int = 90
    PASSWORD_HISTORY_COUNT: int = 6
    MAX_FAILED_ATTEMPTS: int = 5
    LOCKOUT_MINUTES: int = 30

    # Database
    DB_HOST: str = "db"
    DB_PORT: int = 5432
    DB_USER: str = "ofs_app"
    DB_PASSWORD: str
    DB_NAME: str = "ofs_feedback"

    # Auditoria
    AUDIT_RETENTION_DAYS: int = 730

    # Backup
    BACKUP_DIR: str = "/app/backups"
    NAS_BACKUP_PATH: str = ""
    BACKUP_RETENTION_DAILY: int = 30
    BACKUP_RETENTION_WEEKLY: int = 12
    BACKUP_RETENTION_MONTHLY: int = 12

    # Rate Limiting
    RATE_LIMIT_DEFAULT: str = "100/minute"
    RATE_LIMIT_LOGIN: str = "5/minute"

    class Config:
        env_file = ".env"
        extra = "ignore"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    @property
    def database_url_sync(self) -> str:
        return (
            f"postgresql://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )


settings = Settings()
