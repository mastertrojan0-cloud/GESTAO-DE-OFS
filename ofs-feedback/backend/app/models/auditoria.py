"""Compatibilidade: re-exporta AuditLog como AuditoriaLog."""
from app.models.audit_log import AuditLog as AuditoriaLog  # noqa: F401
