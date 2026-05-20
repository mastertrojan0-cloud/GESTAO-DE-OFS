"""
core/audit.py — Escrita de logs de auditoria + decorator @audit.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from functools import wraps
from typing import Any, Callable
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Request


async def write_audit_log(
    db: AsyncSession,
    *,
    user_id: UUID | None = None,
    username: str | None = None,
    action: str,
    entity: str,
    entity_id: str | None = None,
    details: dict[str, Any] | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
    severity: str = "INFO",
) -> None:
    await db.execute(
        text("""
            INSERT INTO audit_logs
                (timestamp, user_id, username, action, entity, entity_id, details,
                 ip_address, user_agent, severity, created_at)
            VALUES
                (:ts, :uid, :uname, :action, :entity, :eid, :details::jsonb,
                 :ip, :ua, :severity, :ts)
        """),
        {
            "ts": datetime.now(timezone.utc),
            "uid": user_id,
            "uname": username,
            "action": action,
            "entity": entity,
            "eid": entity_id,
            "details": json.dumps(details or {}),
            "ip": ip_address,
            "ua": user_agent,
            "severity": severity,
        },
    )
    await db.commit()


def audit(action: str, resource: str = "AUTH", severity: str = "INFO"):
    """
    Decorator que registra automaticamente acoes em audit_logs.
    Extrai current_user e db dos kwargs do endpoint.

    Uso:
        @router.post("/login")
        @audit(action="LOGIN_SUCCESS", resource="AUTH", severity="INFO")
        async def login(...):
            ...
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            result = await func(*args, **kwargs)

            current_user = kwargs.get("current_user")
            db = kwargs.get("db")
            request: Request | None = None
            for v in kwargs.values():
                if isinstance(v, Request):
                    request = v
                    break

            if db is not None:
                try:
                    await write_audit_log(
                        db,
                        user_id=current_user.id if current_user and hasattr(current_user, "id") else None,
                        username=getattr(current_user, "username", None) if current_user else None,
                        action=action,
                        entity=resource,
                        entity_id=None,
                        details={},
                        ip_address=request.client.host if request and request.client else None,
                        user_agent=request.headers.get("user-agent") if request else None,
                        severity=severity,
                    )
                except Exception:
                    pass

            return result
        return wrapper
    return decorator
