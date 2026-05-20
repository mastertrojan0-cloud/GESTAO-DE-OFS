from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import date, datetime, timezone
from uuid import UUID
from typing import Optional

from app.db.session import get_db
from app.core.security import get_current_user, require_role
from app.core.audit import audit
from app.models.usuario import Usuario
from app.models.auditoria import AuditoriaLog
from app.schemas.common import PaginatedResponse
from app.schemas.enums import Severity

router = APIRouter(prefix="/api/admin/audit", tags=["Auditoria"])


@router.get("", response_model=None)
async def list_audit_logs(
    action: Optional[str] = None,
    user_id: Optional[UUID] = None,
    resource: Optional[str] = None,
    severity: Optional[Severity] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user: Usuario = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    query = select(AuditoriaLog)

    if action:
        query = query.where(AuditoriaLog.action == action)
    if user_id:
        query = query.where(AuditoriaLog.usuario_id == user_id)
    if resource:
        query = query.where(AuditoriaLog.resource == resource)
    if severity:
        query = query.where(AuditoriaLog.severity == severity.value)
    if date_from:
        query = query.where(AuditoriaLog.created_at >= date_from)
    if date_to:
        query = query.where(AuditoriaLog.created_at <= date_to)

    query = query.order_by(AuditoriaLog.created_at.desc())

    total_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(total_query)).scalar()

    offset = (page - 1) * limit
    query = query.offset(offset).limit(limit)
    results = (await db.execute(query)).scalars().all()

    return PaginatedResponse(data=results, total=total, page=page, limit=limit)
