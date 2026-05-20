"""
middleware/audit_middleware.py — Middleware que captura 401/403 para auditoria.
Encapsulado no middleware principal (app.core.middleware.AuthorizationMiddleware).
"""

from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response
from starlette.background import BackgroundTask

from app.core.audit import write_audit_log


class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        response = await call_next(request)

        if response.status_code in (401, 403):
            async def _log() -> None:
                from app.db.session import AsyncSessionLocal

                async with AsyncSessionLocal() as session:
                    await write_audit_log(
                        session,
                        user_id=None,
                        username=None,
                        action="PERMISSION_DENIED" if response.status_code == 403 else "LOGIN_FAILED",
                        entity="auth",
                        entity_id=None,
                        details={
                            "path": str(request.url.path),
                            "method": request.method,
                            "status_code": response.status_code,
                        },
                        ip_address=request.client.host if request.client else None,
                        user_agent=request.headers.get("user-agent"),
                        severity="WARN",
                    )

            response.background = BackgroundTask(_log)

        return response
