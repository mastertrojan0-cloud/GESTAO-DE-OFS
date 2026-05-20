from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from fastapi.responses import StreamingResponse
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone, timedelta
from uuid import UUID
from typing import Optional
import io
import csv

from app.db.session import get_db
from app.core.security import (
    get_current_user,
    require_role,
    verify_ofc_access,
    get_data_scope,
    check_edit_window,
    can_edit_ofc,
    can_cancel_ofc,
    can_restore_ofc,
)
from app.core.audit import audit
from app.models.usuario import Usuario
from app.models.ofs import OFS, OFSEditLog
from app.schemas.ofs import OFSCreate, OFSUpdate, OFSFiltros, OFSResp, OFSCancelRequest
from app.schemas.common import PaginatedResponse

router = APIRouter(prefix="/api/ofs", tags=["OFS"])


@router.post("", response_model=OFSResp, status_code=status.HTTP_201_CREATED)
@audit(action="OFS_CREATE", resource="OFS", severity="INFO")
async def create_ofs(
    payload: OFSCreate,
    current_user: Usuario = Depends(require_role("observador", "supervisor", "gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    ofs = OFS(
        data_registro=payload.data,
        hora_registro=payload.hora,
        usuario_id=current_user.id,
        usuario_nome_snapshot=current_user.full_name,
        usuario_email_snapshot=current_user.email,
        usuario_perfil_snapshot=current_user.role,
        empresa_usuario_snapshot=(current_user.company.name if current_user.company else None),
        nome_observado=payload.nome_observado,
        atividade_observada=payload.atividade,
        local_observado=payload.local,
        empresa_observada_id=payload.empresa_observada_id if hasattr(payload, 'empresa_observada_id') else current_user.company_id,
        contrato_id=payload.contrato_id,
        turno=payload.turno.value if hasattr(payload.turno, 'value') else payload.turno,
        tipo_observacao=payload.tipo.value if hasattr(payload.tipo, 'value') else payload.tipo,
        comportamento_observado=payload.comportamento,
        observacao_complementar=payload.observacao or "",
        status_registro="Gerado",
        is_deleted=False,
    )
    db.add(ofs)
    await db.commit()
    await db.refresh(ofs)
    return ofs


@router.get("", response_model=PaginatedResponse[OFSResp])
async def list_ofs(
    filters: OFSFiltros = Depends(),
    current_user: Usuario = Depends(require_role("observador", "supervisor", "gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    scope = get_data_scope(current_user)
    query = select(OFS)
    if scope:
        for k, v in scope.items():
            if v is not None:
                query = query.where(getattr(OFS, k) == v)

    if filters.data_inicio:
        query = query.where(OFS.data >= filters.data_inicio)
    if filters.data_fim:
        query = query.where(OFS.data <= filters.data_fim)
    if filters.tipo_observacao:
        query = query.where(OFS.tipo == filters.tipo_observacao)
    if filters.turno:
        query = query.where(OFS.turno == filters.turno)
    if filters.nome_observado:
        query = query.where(OFS.nome_observado.ilike(f"%{filters.nome_observado}%"))
    if filters.usuario_id:
        query = query.where(OFS.usuario_gerador_id == filters.usuario_id)
    if filters.contrato_id:
        query = query.where(OFS.contrato_id == filters.contrato_id)

    order_col = getattr(OFS, filters.order_by, OFS.created_at)
    if filters.order_dir == "asc":
        query = query.order_by(order_col.asc())
    else:
        query = query.order_by(order_col.desc())

    total_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(total_query)).scalar()

    offset = (filters.page - 1) * filters.page_size
    query = query.offset(offset).limit(filters.page_size)
    results = (await db.execute(query)).scalars().all()

    return PaginatedResponse(
        data=results,
        total=total,
        page=filters.page,
        limit=filters.page_size,
    )


@router.get("/{ofs_id}", response_model=OFSResp)
async def get_ofs(
    ofs_id: UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ofs = await verify_ofc_access(ofs_id, current_user, db)
    return ofs


@router.put("/{ofs_id}", response_model=OFSResp)
@audit(action="OFS_UPDATE", resource="OFS", severity="WARNING")
async def update_ofs(
    ofs_id: UUID,
    payload: OFSUpdate,
    current_user: Usuario = Depends(require_role("observador", "supervisor", "gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    ofs = await verify_ofc_access(ofs_id, current_user, db)
    check_edit_window(ofs, current_user)

    # Optimistic locking
    if ofs.updated_at.replace(tzinfo=timezone.utc) != payload.updated_at.replace(tzinfo=timezone.utc):
        raise HTTPException(
            status_code=409,
            detail="Este registro foi modificado por outro usuario. Recarregue os dados e tente novamente.",
        )

    fields = {"comportamento": payload.comportamento, "observacao": payload.observacao}
    for campo, novo_valor in fields.items():
        if novo_valor is not None:
            antigo = getattr(ofs, campo, "")
            if str(antigo) != str(novo_valor):
                db.add(OFSEditLog(
                    ofs_id=ofs.id,
                    campo=campo,
                    valor_anterior=str(antigo),
                    valor_novo=str(novo_valor),
                    editado_por=current_user.id,
                    editado_em=datetime.now(timezone.utc),
                ))
                setattr(ofs, campo, novo_valor)

    ofs.status = "editado"
    ofs.updated_at = datetime.now(timezone.utc)
    ofs.editado_por = current_user.id
    ofs.editado_em = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(ofs)
    return ofs


@router.delete("/{ofs_id}")
@audit(action="OFS_CANCEL", resource="OFS", severity="WARNING")
async def cancel_ofs(
    ofs_id: UUID,
    payload: OFSCancelRequest,
    current_user: Usuario = Depends(require_role("gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    ofs = await db.get(OFS, ofs_id)
    if not ofs:
        raise HTTPException(status_code=404, detail="OFS nao encontrada.")
    if ofs.is_deleted:
        raise HTTPException(status_code=400, detail="OFS ja esta cancelada.")

    ofs.is_deleted = True
    ofs.motivo_cancelamento = payload.motivo
    ofs.cancelado_por = current_user.id
    ofs.cancelado_em = datetime.now(timezone.utc)
    ofs.status = "cancelado"

    await db.commit()
    return {"message": "OFS cancelada com sucesso."}


@router.post("/{ofs_id}/restore")
@audit(action="OFS_RESTORE", resource="OFS", severity="WARNING")
async def restore_ofs(
    ofs_id: UUID,
    current_user: Usuario = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    ofs = await db.get(OFS, ofs_id)
    if not ofs or not ofs.is_deleted:
        raise HTTPException(status_code=404, detail="OFS cancelada nao encontrada.")

    ofs.is_deleted = False
    ofs.restaurado_por = current_user.id
    ofs.restaurado_em = datetime.now(timezone.utc)
    ofs.status = "editado"

    await db.commit()
    return {"message": "OFS restaurada com sucesso."}


@router.get("/export/csv")
@audit(action="OFS_EXPORT", resource="OFS", severity="INFO")
async def export_ofs_csv(
    filters: OFSFiltros = Depends(),
    current_user: Usuario = Depends(require_role("observador", "supervisor", "gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    scope = get_data_scope(current_user)
    query = select(OFS)
    if scope:
        for k, v in scope.items():
            if v is not None:
                query = query.where(getattr(OFS, k) == v)
    results = (await db.execute(query)).scalars().all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["ID", "Data", "Hora", "GeradoPor", "Observado", "Atividade",
                      "Local", "Empresa", "Turno", "Tipo", "Comportamento", "Status", "CriadoEm"])
    for o in results:
        writer.writerow([
            o.id, o.data, o.hora, o.usuario_gerador_nome, o.nome_observado,
            o.atividade, o.local, o.empresa_nome, o.turno, o.tipo,
            o.comportamento, o.status, o.created_at.isoformat()
        ])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=ofs_export.csv"},
    )
