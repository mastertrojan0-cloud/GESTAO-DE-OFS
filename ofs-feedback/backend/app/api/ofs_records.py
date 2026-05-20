"""
ofs_records.py — Router CRUD de OFS (Sistema Security Dynamics).

Rotas:
  POST   /api/ofs-records           — Criar novo registro
  GET    /api/ofs-records           — Listar com filtros (paginado)
  GET    /api/ofs-records/{id}      — Detalhe completo com historico de edicoes
  PUT    /api/ofs-records/{id}      — Editar (com janela de edicao + optimistic lock)
  PATCH  /api/ofs-records/{id}/cancel — Cancelar (soft delete, gestor/admin)
  GET    /api/ofs-records/{id}/pdf  — Gerar PDF individual
  POST   /api/ofs-records/{id}/restore — Restaurar (admin apenas)
"""

from datetime import datetime, timezone
from uuid import UUID
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import get_current_user, require_role
from app.core.audit import audit
from app.models.usuario import Usuario
from app.schemas.ofs import (
    OfsCreate,
    OfsUpdate,
    OfsFiltros,
    OfsResponse,
    OfsDetailResponse,
    OfsUpdateResponse,
    OfsCancelRequest,
    CancelResponse,
    EditLogEntry,
)
from app.schemas.common import PaginatedResponse
from app.services.ofs_service import (
    create_ofs_record,
    get_ofs_record,
    get_ofs_edit_history,
    list_ofs_records,
    update_ofs_record,
    cancel_ofs_record,
    restore_ofs_record,
    generate_ofs_pdf_data,
)

router = APIRouter(prefix="/api/ofs-records", tags=["OFS Records"])

ALL_ROLES = ["observador", "supervisor", "gestor", "admin"]


# ═══════════════════════════════════════════════════════════════════════
# POST /api/ofs-records — Criar novo registro OFS
# ═══════════════════════════════════════════════════════════════════════

@router.post("", response_model=OfsResponse, status_code=status.HTTP_201_CREATED)
@audit(action="OFS_CREATE", resource="OFS", severity="INFO")
async def create_record(
    payload: OfsCreate,
    current_user: Usuario = Depends(require_role(*ALL_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    ofs = await create_ofs_record(db, payload, current_user)
    await db.commit()
    await db.refresh(ofs)
    return ofs


# ═══════════════════════════════════════════════════════════════════════
# GET /api/ofs-records — Listar com filtros
# ═══════════════════════════════════════════════════════════════════════

@router.get("", response_model=PaginatedResponse[OfsResponse])
async def list_records(
    codigo: Optional[str] = Query(None, description="Filtro parcial por codigo (ex: OFS-25-)"),
    data_inicio: Optional[str] = Query(None, description="Data inicio YYYY-MM-DD"),
    data_fim: Optional[str] = Query(None, description="Data fim YYYY-MM-DD"),
    semana: Optional[int] = Query(None, ge=1, le=53, description="Numero da semana ISO"),
    mes: Optional[int] = Query(None, ge=1, le=12, description="Mes (1-12)"),
    ano: Optional[int] = Query(None, description="Ano (ex: 2025)"),
    usuario_id: Optional[UUID] = Query(None, description="ID do usuario gerador"),
    empresa_observada_id: Optional[UUID] = Query(None, description="ID da empresa observada"),
    contrato_id: Optional[UUID] = Query(None, description="ID do contrato"),
    turno: Optional[str] = Query(None, description="Turno: ADM, 1, 2, 3"),
    tipo_observacao: Optional[str] = Query(None, description="Tipo: Positivo (Seguro) ou Negativo (Inseguro)"),
    status_registro: Optional[str] = Query(None, description="Status: ativo, editado, cancelado"),
    nome_observado: Optional[str] = Query(None, description="Nome parcial do observado"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    order_by: str = Query("created_at"),
    order_dir: str = Query("desc"),
    include_deleted: bool = Query(False),
    current_user: Usuario = Depends(require_role(*ALL_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    result = await list_ofs_records(
        db=db,
        current_user=current_user,
        codigo=codigo,
        data_inicio=data_inicio,
        data_fim=data_fim,
        semana=semana,
        mes=mes,
        ano=ano,
        usuario_id=usuario_id,
        empresa_observada_id=empresa_observada_id,
        contrato_id=contrato_id,
        turno=turno,
        tipo_observacao=tipo_observacao,
        status_registro=status_registro,
        nome_observado=nome_observado,
        page=page,
        limit=page_size,
        order_by=order_by,
        order_dir=order_dir,
    )
    return PaginatedResponse(
        data=result["data"],
        total=result["total"],
        page=result["page"],
        limit=result["limit"],
    )


# ═══════════════════════════════════════════════════════════════════════
# GET /api/ofs-records/{id} — Detalhe completo com historico de edicoes
# ═══════════════════════════════════════════════════════════════════════

@router.get("/{record_id}", response_model=OfsDetailResponse)
async def get_record(
    record_id: UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ofs = await get_ofs_record(record_id, current_user, db)
    edit_logs = await get_ofs_edit_history(record_id, db)
    return OfsDetailResponse(
        registro=ofs,
        edicoes=[EditLogEntry.model_validate(log) for log in edit_logs],
    )


# ═══════════════════════════════════════════════════════════════════════
# PUT /api/ofs-records/{id} — Editar registro
# ═══════════════════════════════════════════════════════════════════════

@router.put("/{record_id}", response_model=OfsUpdateResponse)
@audit(action="OFS_UPDATE", resource="OFS", severity="WARNING")
async def update_record(
    record_id: UUID,
    payload: OfsUpdate,
    current_user: Usuario = Depends(require_role(*ALL_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    ofs, edit_logs = await update_ofs_record(record_id, payload, current_user, db)
    await db.commit()
    await db.refresh(ofs)
    return OfsUpdateResponse(
        registro=ofs,
        edicoes_realizadas=edit_logs,
    )


# ═══════════════════════════════════════════════════════════════════════
# PATCH /api/ofs-records/{id}/cancel — Cancelar (soft delete)
# ═══════════════════════════════════════════════════════════════════════

@router.patch("/{record_id}/cancel", response_model=CancelResponse)
@audit(action="OFS_CANCEL", resource="OFS", severity="WARNING")
async def cancel_record(
    record_id: UUID,
    payload: OfsCancelRequest,
    current_user: Usuario = Depends(require_role("gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    ofs = await cancel_ofs_record(record_id, payload.motivo, current_user, db)
    await db.commit()
    await db.refresh(ofs)
    return CancelResponse(
        message="Registro cancelado com sucesso.",
        id=ofs.id,
        status=ofs.status,
        cancelado_em=ofs.cancelado_em or datetime.now(timezone.utc),
    )


# ═══════════════════════════════════════════════════════════════════════
# POST /api/ofs-records/{id}/restore — Restaurar registro cancelado
# ═══════════════════════════════════════════════════════════════════════

@router.post("/{record_id}/restore")
@audit(action="OFS_RESTORE", resource="OFS", severity="WARNING")
async def restore_record(
    record_id: UUID,
    current_user: Usuario = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    ofs = await restore_ofs_record(record_id, current_user, db)
    await db.commit()
    await db.refresh(ofs)
    return {"message": "Registro restaurado com sucesso.", "id": str(ofs.id), "status": ofs.status}


# ═══════════════════════════════════════════════════════════════════════
# GET /api/ofs-records/{id}/pdf — Gerar PDF individual
# ═══════════════════════════════════════════════════════════════════════

@router.get("/{record_id}/pdf")
@audit(action="OFS_PDF", resource="OFS", severity="INFO")
async def download_pdf(
    record_id: UUID,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ofs = await get_ofs_record(record_id, current_user, db)
    edit_logs = await get_ofs_edit_history(record_id, db)

    pdf_data = generate_ofs_pdf_data(ofs, edit_logs)

    try:
        from app.services.pdf_service import generate_report

        result = generate_report("individual", pdf_data)
        return StreamingResponse(
            result.file_path.open("rb"),
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'inline; filename="{result.file_name}"',
                "X-Report-Id": result.report_id,
            },
        )
    except ImportError:
        raise HTTPException(
            status_code=500,
            detail="WeasyPrint nao esta instalado. Execute: pip install weasyprint",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao gerar PDF: {str(e)}")
