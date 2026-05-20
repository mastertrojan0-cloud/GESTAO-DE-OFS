"""
core/decorators.py — Decorators para auditoria automatica de acoes OFS.
"""

from __future__ import annotations

from functools import wraps
from typing import Callable, Any

from fastapi import Request

from app.core.audit import write_audit_log


def audit_ofc_action(action: str, severity: str = "INFO"):
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            result = await func(*args, **kwargs)

            current_user = None
            request = None
            ofc_id = kwargs.get("ofc_id", None)
            db = kwargs.get("db")

            for v in kwargs.values():
                if hasattr(v, "perfil") and hasattr(v, "id"):
                    current_user = v
                if isinstance(v, Request):
                    request = v

            if current_user is not None and db is not None:
                await write_audit_log(
                    db,
                    user_id=current_user.id if hasattr(current_user, "id") else None,
                    username=getattr(current_user, "nome", None),
                    action=action,
                    entity="ofc_records",
                    entity_id=str(ofc_id) if ofc_id else None,
                    ip_address=request.client.host if request and request.client else None,
                    user_agent=request.headers.get("user-agent") if request else None,
                    severity=severity,
                )

            return result
        return wrapper
    return decorator
