# core/optimistic_lock.py
"""Optimistic locking para edição de OFS — prevenção de conflitos de concorrência."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID
from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

if TYPE_CHECKING:
    from app.models import OfcRecord


async def check_optimistic_lock(
    db: AsyncSession,
    ofc_id: UUID,
    client_updated_at: datetime,
) -> OfcRecord:
    """
    Busca o OFS e verifica conflito de concorrência via updated_at.

    Se o updated_at do banco for diferente do enviado pelo cliente:
        → HTTP 409 Conflict (outro usuário editou antes).

    Raises:
        HTTPException(404): Registro não encontrado
        HTTPException(409): Conflito de concorrência
    """
    from app.models import OfcRecord

    result = await db.execute(
        select(OfcRecord).where(OfcRecord.id == ofc_id)
    )
    OFS = result.scalar_one_or_none()

    if not OFS:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Registro não encontrado")

    if OFS.updated_at != client_updated_at:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            detail={
                "error": "concurrency_conflict",
                "message": "Registro foi modificado por outro usuário. Recarregue e tente novamente.",
                "server_updated_at": OFS.updated_at.isoformat(),
                "client_updated_at": client_updated_at.isoformat(),
            },
        )

    return OFS
