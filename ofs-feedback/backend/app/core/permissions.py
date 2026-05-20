"""
core/permissions.py — Re-export dos controles de acesso RBAC.
Funcoes consolidadas em app.core.security.
"""

from app.core.security import (
    PERMISSIONS,
    EDIT_WINDOWS,
    ROLE_HIERARCHY,
    has_permission,
    has_any_permission,
    can_edit_ofc,
    can_cancel_ofc,
    can_restore_ofc,
    check_edit_window,
)

__all__ = [
    "PERMISSIONS",
    "EDIT_WINDOWS",
    "ROLE_HIERARCHY",
    "has_permission",
    "has_any_permission",
    "can_edit_ofc",
    "can_cancel_ofc",
    "can_restore_ofc",
    "check_edit_window",
]
