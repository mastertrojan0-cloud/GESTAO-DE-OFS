"""
core/middleware.py — AuthMiddleware + AuditMiddleware.
Autentica todas as rotas exceto publicas. Captura 401/403 em audit_logs.
"""

from __future__ import annotations

import logging
from fastapi import Request, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from starlette.background import BackgroundTask
from jose import jwt, JWTError, ExpiredSignatureError  # noqa: F811

from app.core.config import settings

logger = logging.getLogger("ofs.middleware")

PUBLIC_PATH_PREFIXES: set[str] = {
    "/api/health",
    "/api/docs",
    "/api/auth/login",
    "/api/auth/refresh",
    "/api/openapi.json",
}

_ROUTE_PERMISSIONS: dict[tuple[str, str], list[str]] = {
    ("POST", "/api/OFS"): ["observador", "supervisor", "gestor", "admin"],
    ("GET", "/api/OFS"): ["observador", "supervisor", "gestor", "admin"],
    ("PUT", "/api/OFS"): ["observador", "supervisor", "gestor", "admin"],
    ("DELETE", "/api/OFS"): ["gestor", "admin"],
    ("GET", "/api/metricas"): ["supervisor", "gestor", "admin"],
    ("GET", "/api/metrics"): ["observador", "supervisor", "gestor", "admin"],
    ("POST", "/api/metrics"): ["gestor", "admin"],
    ("POST", "/api/OFS-records"): ["observador", "supervisor", "gestor", "admin"],
    ("GET", "/api/OFS-records"): ["observador", "supervisor", "gestor", "admin"],
    ("PUT", "/api/OFS-records"): ["observador", "supervisor", "gestor", "admin"],
    ("PATCH", "/api/OFS-records"): ["gestor", "admin"],
    ("DELETE", "/api/OFS-records"): ["gestor", "admin"],
    ("GET", "/api/reports/generate"): ["gestor", "admin"],
    ("POST", "/api/reports"): ["gestor", "admin"],
    ("GET", "/api/admin"): ["admin"],
    ("POST", "/api/admin"): ["admin"],
    ("PUT", "/api/admin"): ["admin"],
    ("DELETE", "/api/admin"): ["admin"],
    ("GET", "/api/audit"): ["admin"],
}


def _extract_token_from_header(auth_header: str | None) -> str | None:
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    return auth_header.removeprefix("Bearer ").strip()


def _decode_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "access":
            return None
        return payload
    except (JWTError, ExpiredSignatureError):
        return None


def _match_permission(method: str, path: str) -> list[str] | None:
    for (route_method, route_prefix), allowed in _ROUTE_PERMISSIONS.items():
        if method.upper() == route_method and path.startswith(route_prefix):
            return allowed
    return None


def _is_public_path(path: str) -> bool:
    return any(path.startswith(p) for p in PUBLIC_PATH_PREFIXES)


async def _write_audit_async(
    action: str,
    path: str,
    method: str,
    status_code: int,
    ip_address: str | None,
    user_agent: str | None,
) -> None:
    try:
        from app.db.session import AsyncSessionLocal
        from app.core.audit import write_audit_log

        async with AsyncSessionLocal() as db:
            await write_audit_log(
                db,
                user_id=None,
                username=None,
                action=action,
                entity="auth",
                entity_id=None,
                details={
                    "path": path,
                    "method": method,
                    "status_code": status_code,
                },
                ip_address=ip_address,
                user_agent=user_agent,
                severity="WARN",
            )
    except Exception:
        logger.exception("Falha ao escrever audit_log no middleware")


class AuthorizationMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        method = request.method

        if _is_public_path(path):
            return await call_next(request)

        auth_header = request.headers.get("Authorization")
        token = _extract_token_from_header(auth_header)
        if not token:
            status_code = status.HTTP_401_UNAUTHORIZED
            payload = {"detail": "Token de autenticacao nao fornecido."}
            bg = BackgroundTask(
                _write_audit_async,
                "LOGIN_FAILED",
                path,
                method,
                status_code,
                request.client.host if request.client else None,
                request.headers.get("user-agent"),
            )
            return JSONResponse(
                status_code=status_code,
                content=payload,
                headers={"WWW-Authenticate": "Bearer"},
                background=bg,
            )

        token_payload = _decode_token(token)
        if not token_payload:
            status_code_val = status.HTTP_401_UNAUTHORIZED
            resp_payload = {"detail": "Token invalido ou expirado."}
            bg = BackgroundTask(
                _write_audit_async,
                "LOGIN_FAILED",
                path,
                method,
                status_code_val,
                request.client.host if request.client else None,
                request.headers.get("user-agent"),
            )
            return JSONResponse(
                status_code=status_code_val,
                content=resp_payload,
                headers={"WWW-Authenticate": "Bearer"},
                background=bg,
            )

        user_perfil = token_payload.get("role", "")
        user_id = token_payload.get("sub", "")

        allowed = _match_permission(method, path)
        if allowed is not None and user_perfil not in allowed:
            logger.warning(
                "PERMISSION_DENIED middleware | user=%s perfil=%s path=%s method=%s allowed=%s",
                user_id, user_perfil, path, method, allowed,
            )
            status_code_val = status.HTTP_403_FORBIDDEN
            resp_payload = {"detail": "Seu perfil nao tem permissao para acessar este recurso."}
            bg = BackgroundTask(
                _write_audit_async,
                "PERMISSION_DENIED",
                path,
                method,
                status_code_val,
                request.client.host if request.client else None,
                request.headers.get("user-agent"),
            )
            return JSONResponse(
                status_code=status_code_val,
                content=resp_payload,
                background=bg,
            )

        request.state.user_id = user_id
        request.state.user_perfil = user_perfil

        return await call_next(request)
