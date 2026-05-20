"""
deps.py — FastAPI Dependencies para autenticacao e autorizacao.
Uso nos routers: Depends(get_current_user), Depends(require_role("gestor"))
"""

from app.core.security import (
    get_current_user,
    require_role,
    require_permission,
    get_data_scope,
    has_permission,
    has_any_permission,
    decode_token,
)

__all__ = [
    "get_current_user",
    "require_role",
    "require_permission",
    "get_data_scope",
    "has_permission",
    "has_any_permission",
    "decode_token",
]
