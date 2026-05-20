from datetime import datetime, timezone, timedelta, date
from typing import Optional, Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select, func, and_, or_, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.ofs_record import OfsRecord, OfsEditLog
from app.models.user import User
from app.models.audit_log import AuditLog

EDIT_WINDOWS: dict[str, Optional[timedelta]] = {
    "observador": timedelta(hours=24),
    "supervisor": timedelta(hours=48),
    "gestor": None,
    "admin": None,
}

CAN_CANCEL = {"gestor", "admin"}
CAN_RESTORE = {"admin"}

EDITABLE_FIELDS = {
    "empresa_observada_id", "empresa_observada_outros",
    "nome_observado", "atividade_observada", "local_observado",
    "turno", "tipo_observacao",
    "comportamento_observado", "observacao_complementar",
}


def _apply_data_scope(
    query: Any,
    user: User,
    include_deleted: bool = False,
) -> Any:
    if user.role == "observador":
        query = query.where(OfsRecord.criado_por == user.id)
    elif user.role == "supervisor":
        query = query.where(OfsRecord.empresa_observada_id == user.company_id)
    if not include_deleted and user.role != "admin":
        query = query.where(OfsRecord.is_deleted == False)
    return query


def _check_edit_window(ofs: OfsRecord, user: User) -> None:
    window = EDIT_WINDOWS.get(user.role)
    if window is None:
        return
    deadline = ofs.criado_em + window
    if datetime.now(timezone.utc) > deadline:
        horas = int(window.total_seconds() / 3600)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Janela de edicao expirada ({horas}h apos criacao).",
        )


async def _write_audit(
    db: AsyncSession,
    user: User,
    action: str,
    resource: str,
    resource_id: Optional[str] = None,
    details: Optional[dict] = None,
    severity: str = "INFO",
) -> None:
    log = AuditLog(
        timestamp=datetime.now(timezone.utc),
        user_id=user.id,
        username=user.username,
        action=action,
        resource=resource,
        resource_id=str(resource_id) if resource_id else None,
        details=details or {},
        severity=severity,
        created_at=datetime.now(timezone.utc),
    )
    db.add(log)


async def create_ofs(
    db: AsyncSession,
    data: Any,
    current_user: User,
) -> OfsRecord:
    now = datetime.now(timezone.utc)
    today = data.data_registro if data.data_registro else date.today()

    ofs = OfsRecord(
        data_registro=today,
        hora_registro=data.hora_registro or now.time(),
        usuario_id=current_user.id,
        usuario_nome_snapshot=current_user.full_name,
        usuario_login_snapshot=current_user.username,
        usuario_email_snapshot=current_user.email,
        usuario_perfil_snapshot=current_user.role,
        empresa_usuario_snapshot=current_user.company.name if current_user.company else None,
        contrato_id=data.contrato_id,
        empresa_observada_id=data.empresa_observada_id,
        empresa_observada_outros=data.empresa_observada_outros,
        nome_observado=data.nome_observado,
        atividade_observada=data.atividade_observada,
        local_observado=data.local_observado,
        turno=data.turno,
        tipo_observacao=data.tipo_observacao,
        comportamento_observado=data.comportamento_observado,
        observacao_complementar=data.observacao_complementar,
        status_registro="Gerado",
        is_deleted=False,
        edit_count=0,
        criado_por=current_user.id,
        criado_em=now,
        updated_at=now,
    )
    db.add(ofs)

    await _write_audit(
        db, current_user,
        action="OFS_CREATE",
        resource="ofs_records",
        severity="INFO",
    )

    await db.flush()
    await db.refresh(ofs)
    return ofs


async def get_ofs(
    db: AsyncSession,
    ofs_id: UUID,
    current_user: User,
) -> OfsRecord:
    query = (
        select(OfsRecord)
        .options(selectinload(OfsRecord.edit_logs))
        .options(selectinload(OfsRecord.usuario))
        .options(selectinload(OfsRecord.empresa_observada))
        .options(selectinload(OfsRecord.contrato))
        .where(OfsRecord.id == ofs_id)
    )
    query = _apply_data_scope(query, current_user)

    result = await db.execute(query)
    ofs = result.scalar_one_or_none()

    if not ofs:
        raise HTTPException(status_code=404, detail="Registro OFS nao encontrado.")

    if ofs.is_deleted and current_user.role not in ("gestor", "admin"):
        raise HTTPException(status_code=404, detail="Registro OFS nao encontrado.")

    return ofs


async def list_ofs(
    db: AsyncSession,
    current_user: User,
    codigo: Optional[str] = None,
    data_inicio: Optional[date] = None,
    data_fim: Optional[date] = None,
    semana: Optional[int] = None,
    mes: Optional[int] = None,
    ano: Optional[int] = None,
    usuario_id: Optional[UUID] = None,
    empresa_observada_id: Optional[int] = None,
    contrato_id: Optional[int] = None,
    turno: Optional[str] = None,
    tipo_observacao: Optional[str] = None,
    status_registro: Optional[str] = None,
    nome_observado: Optional[str] = None,
    page: int = 1,
    limit: int = 25,
    order_by: str = "criado_em",
    order_dir: str = "desc",
) -> dict:
    query = select(OfsRecord)
    query = _apply_data_scope(query, current_user)

    if codigo:
        query = query.where(OfsRecord.codigo.ilike(f"%{codigo}%"))
    if data_inicio:
        query = query.where(OfsRecord.data_registro >= data_inicio)
    if data_fim:
        query = query.where(OfsRecord.data_registro <= data_fim)
    if semana is not None:
        query = query.where(OfsRecord.semana == semana)
    if mes is not None:
        query = query.where(OfsRecord.mes == mes)
    if ano is not None:
        query = query.where(OfsRecord.ano == ano)
    if usuario_id:
        query = query.where(OfsRecord.criado_por == usuario_id)
    if empresa_observada_id:
        query = query.where(OfsRecord.empresa_observada_id == empresa_observada_id)
    if contrato_id:
        query = query.where(OfsRecord.contrato_id == contrato_id)
    if turno:
        query = query.where(OfsRecord.turno == turno)
    if tipo_observacao:
        query = query.where(OfsRecord.tipo_observacao == tipo_observacao)
    if status_registro:
        query = query.where(OfsRecord.status_registro == status_registro)
    if nome_observado:
        query = query.where(OfsRecord.nome_observado.ilike(f"%{nome_observado}%"))

    order_col = getattr(OfsRecord, order_by, OfsRecord.criado_em)
    if order_dir == "asc":
        query = query.order_by(order_col.asc())
    else:
        query = query.order_by(order_col.desc())

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    offset = (page - 1) * limit
    query = query.offset(offset).limit(limit)
    results = (await db.execute(query)).scalars().all()

    total_pages = (total + limit - 1) // limit if total > 0 else 0

    return {
        "data": list(results),
        "total": total,
        "page": page,
        "limit": limit,
        "total_pages": total_pages,
    }


async def update_ofs(
    db: AsyncSession,
    ofs_id: UUID,
    data: Any,
    current_user: User,
) -> tuple[OfsRecord, list[dict]]:
    ofs = await get_ofs(db, ofs_id, current_user)

    if ofs.status_registro == "Cancelado":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registro cancelado nao pode ser editado.",
        )

    if current_user.role == "observador" and ofs.criado_por != current_user.id:
        raise HTTPException(status_code=403, detail="Voce so pode editar seus proprios registros.")

    if current_user.role == "supervisor" and ofs.empresa_observada_id != current_user.company_id:
        raise HTTPException(status_code=403, detail="Voce so pode editar registros da sua empresa.")

    _check_edit_window(ofs, current_user)

    if ofs.updated_at.replace(tzinfo=timezone.utc) != data.updated_at.replace(tzinfo=timezone.utc):
        raise HTTPException(
            status_code=409,
            detail="Registro foi modificado por outro usuario. Recarregue e tente novamente.",
        )

    now = datetime.now(timezone.utc)
    edit_logs = []
    field_map = {
        "empresa_observada_id": data.empresa_observada_id,
        "empresa_observada_outros": data.empresa_observada_outros,
        "nome_observado": data.nome_observado,
        "atividade_observada": data.atividade_observada,
        "local_observado": data.local_observado,
        "turno": data.turno,
        "tipo_observacao": data.tipo_observacao,
        "comportamento_observado": data.comportamento_observado,
        "observacao_complementar": data.observacao_complementar,
    }

    for campo, novo_valor in field_map.items():
        if novo_valor is None:
            continue
        old_raw = getattr(ofs, campo, None)
        old_str = str(old_raw) if old_raw is not None else ""
        new_str = str(novo_valor) if novo_valor is not None else ""
        if old_str != new_str:
            log = OfsEditLog(
                ofs_record_id=ofs.id,
                edited_by=current_user.id,
                field_changed=campo,
                old_value=old_str,
                new_value=new_str,
                edited_at=now,
            )
            db.add(log)
            edit_logs.append({
                "campo": campo,
                "valor_anterior": old_str,
                "valor_novo": new_str,
            })
            setattr(ofs, campo, novo_valor)

    ofs.status_registro = "Editado"
    ofs.edit_count = (ofs.edit_count or 0) + 1
    ofs.editado_por = current_user.id
    ofs.editado_em = now
    ofs.updated_at = now

    await _write_audit(
        db, current_user,
        action="OFS_UPDATE",
        resource="ofs_records",
        resource_id=str(ofs_id),
        details={"campos_alterados": [e["campo"] for e in edit_logs], "edit_count": ofs.edit_count},
        severity="WARNING",
    )

    await db.flush()
    await db.refresh(ofs)
    return ofs, edit_logs


async def cancel_ofs(
    db: AsyncSession,
    ofs_id: UUID,
    motivo_cancelamento: str,
    current_user: User,
) -> OfsRecord:
    if current_user.role not in CAN_CANCEL:
        raise HTTPException(
            status_code=403,
            detail="Apenas Gestor e Admin podem cancelar registros.",
        )

    ofs = await db.get(OfsRecord, ofs_id)
    if not ofs:
        raise HTTPException(status_code=404, detail="Registro OFS nao encontrado.")
    if ofs.is_deleted:
        raise HTTPException(status_code=400, detail="Registro ja esta cancelado.")

    now = datetime.now(timezone.utc)
    ofs.is_deleted = True
    ofs.status_registro = "Cancelado"
    ofs.cancelado_por = current_user.id
    ofs.cancelado_em = now
    ofs.motivo_cancelamento = motivo_cancelamento
    ofs.updated_at = now

    await _write_audit(
        db, current_user,
        action="OFS_CANCEL",
        resource="ofs_records",
        resource_id=str(ofs_id),
        details={"motivo": motivo_cancelamento},
        severity="WARNING",
    )

    await db.flush()
    await db.refresh(ofs)
    return ofs


async def restore_ofs(
    db: AsyncSession,
    ofs_id: UUID,
    current_user: User,
) -> OfsRecord:
    if current_user.role not in CAN_RESTORE:
        raise HTTPException(
            status_code=403,
            detail="Apenas Admin pode restaurar registros.",
        )

    ofs = await db.get(OfsRecord, ofs_id)
    if not ofs:
        raise HTTPException(status_code=404, detail="Registro OFS nao encontrado.")
    if not ofs.is_deleted:
        raise HTTPException(status_code=400, detail="Registro nao esta cancelado.")

    now = datetime.now(timezone.utc)
    ofs.is_deleted = False
    ofs.status_registro = "Editado"
    ofs.deleted_by = None
    ofs.updated_at = now

    await _write_audit(
        db, current_user,
        action="OFS_RESTORE",
        resource="ofs_records",
        resource_id=str(ofs_id),
        severity="CRITICAL",
    )

    await db.flush()
    await db.refresh(ofs)
    return ofs


async def get_ofs_edit_history(ofs_id: UUID, db: AsyncSession) -> list[OfsEditLog]:
    result = await db.execute(
        select(OfsEditLog)
        .where(OfsEditLog.ofs_record_id == ofs_id)
        .order_by(OfsEditLog.edited_at.desc())
    )
    return list(result.scalars().all())


# ============================================================
# Aliases de compatibilidade (legacy API modules)
# ============================================================
create_ofs_record = create_ofs
get_ofs_record = get_ofs
list_ofs_records = list_ofs
update_ofs_record = update_ofs
cancel_ofs_record = cancel_ofs
restore_ofs_record = restore_ofs

# OFS legacy aliases
create_ofc = create_ofs
get_ofc = get_ofs
list_ofs_records = list_ofs
update_ofc = update_ofs
cancel_ofc = cancel_ofs
restore_ofc = restore_ofs
get_ofc_edit_history = get_ofs_edit_history
create_ofc_record = create_ofs
get_ofc_record = get_ofs
list_ofc_records = list_ofs
update_ofc_record = update_ofs
cancel_ofc_record = cancel_ofs
restore_ofc_record = restore_ofs


def generate_ofs_pdf_data(ofs: OfsRecord, edit_logs: list[OfsEditLog]) -> dict:
    """Prepara dados do OFS para geracao de PDF."""
    return {
        "ofs": ofs,
        "edicoes": edit_logs,
        "total_edicoes": len(edit_logs),
    }


# Legacy alias
def generate_ofc_pdf_data(ofs: OfsRecord, edit_logs: list[OfsEditLog]) -> dict:
    return generate_ofs_pdf_data(ofs, edit_logs)
