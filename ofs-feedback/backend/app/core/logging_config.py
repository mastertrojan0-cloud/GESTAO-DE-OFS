import os
import logging.config
import re

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")


class SanitizingFormatter(logging.Formatter):
    """Remove dados sensiveis dos logs."""

    SENSITIVE_PATTERNS = [
        (r'(password["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
        (r'(token["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
        (r'(secret["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
        (r'(Bearer\s+)([^\s]+)', r'\1[REDACTED]'),
        (r'(password_hash["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
    ]

    def format(self, record):
        msg = super().format(record)
        for pattern, replacement in self.SENSITIVE_PATTERNS:
            msg = re.sub(pattern, replacement, msg, flags=re.IGNORECASE)
        return msg


def setup_logging():
    """Configura logging com formatador que redacta dados sensiveis."""
    config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "default": {
                "()": "app.core.logging_config.SanitizingFormatter",
                "format": "[%(asctime)s] %(levelname)s %(name)s: %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "default",
                "stream": "ext://sys.stdout",
            },
        },
        "root": {
            "level": LOG_LEVEL,
            "handlers": ["console"],
        },
        "loggers": {
            "uvicorn": {"level": LOG_LEVEL, "handlers": ["console"], "propagate": False},
            "sqlalchemy": {"level": "WARNING", "handlers": ["console"], "propagate": False},
        },
    }
    logging.config.dictConfig(config)
