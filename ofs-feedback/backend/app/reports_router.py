"""
FastAPI Router para endpoints de Relatorios PDF e Excel.
Sistema OFS/OFS — Security Dynamics
"""
import re
import uuid
import logging
from datetime import datetime, date, timedelta, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import get_current_user, require_role
from app.core.audit import write_audit_log
from app.core.compat import user_to_adapter
from app.models.user import User
from app.services.pdf_service import (
    generate_ofc_pdf,
    generate_weekly_pdf,
    generate_monthly_pdf,
)
from app.services.excel_service import export_weekly_excel_bytes

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/reports", tags=["Relatorios"])

ALL_ROLES = ["observador", "supervisor", "gestor", "admin"]
STAFF_ROLES = ["supervisor", "gestor", "admin"]


def _parse_date(value: str) -> date:
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", value):
        raise HTTPException(status_code=400, detail=f"Data invalida: {value}. Use YYYY-MM-DD.")
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Data invalida: {value}. Use YYYY-MM-DD.")


def _week_start_from_date(ref_date: date) -> date:
    return ref_date - timedelta(days=ref_date.weekday())


def _month_start_from_date(ref_date: date) -> date:
    return ref_date.replace(day=1)


async def _log_report_generation(
    db: AsyncSession,
    user: User,
    action: str,
    report_type: str,
    params: dict,
    file_size: int = 0,
    request: Request | None = None,
):
    try:
        await write_audit_log(
            db,
            user_id=user.id,
            username=user.username,
            action=action,
            entity="REPORT",
            entity_id=str(uuid.uuid4()),
            details={
                "report_type": report_type,
                "parameters": {k: str(v) for k, v in params.items()},
                "file_size_bytes": file_size,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
            ip_address=request.client.host if request else None,
            user_agent=request.headers.get("user-agent", "") if request else "",
            severity="INFO",
        )
    except Exception as e:
        logger.warning(f"Falha ao registrar auditoria de relatorio: {e}")


# ═══════════════════════════════════════════════════════════════════════
# 1. PDF INDIVIDUAL OFS
# ═══════════════════════════════════════════════════════════════════════

@router.get("/OFS/{ofc_id}/pdf")
async def get_ofc_individual_pdf(
    ofc_id: UUID,
    request: Request,
    current_user: User = Depends(require_role(*ALL_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    """
    Gera PDF individual de um registro OFS/OFS.
    Pipeline: busca OFS -> renderiza Jinja2 -> WeasyPrint -> StreamingResponse
    """
    try:
        pdf_bytes = await generate_ofc_pdf(ofc_id, db)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ImportError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.exception("Erro ao gerar PDF individual")
        raise HTTPException(status_code=500, detail=f"Erro ao gerar PDF: {str(e)}")

    file_name = f"OFC_INDIVIDUAL_{ofc_id}_{datetime.now().strftime('%Y%m%d')}.pdf"
    await _log_report_generation(
        db, current_user, "GERAR_PDF", "individual",
        {"ofc_id": str(ofc_id)}, len(pdf_bytes), request,
    )

    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{file_name}"',
            "Content-Length": str(len(pdf_bytes)),
            "X-Report-Type": "individual",
            "X-Report-OFS-Id": str(ofc_id),
        },
    )


# ═══════════════════════════════════════════════════════════════════════
# 2. PDF METRICAS DA SEMANA
# ═══════════════════════════════════════════════════════════════════════

@router.get("/week/pdf")
async def get_weekly_metrics_pdf(
    request: Request,
    week_start: str = Query(..., description="Segunda-feira da semana (YYYY-MM-DD)"),
    company_id: Optional[int] = Query(None, description="Filtrar por empresa"),
    current_user: User = Depends(require_role(*ALL_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    """
    Gera PDF de Metricas da Semana com 4 graficos:
    Programado x Realizado, Positivo x Negativo, Empresa, Evolucao.
    """
    try:
        inicio = _parse_date(week_start)
    except HTTPException:
        raise HTTPException(status_code=400, detail=f"week_start invalido: {week_start}")

    inicio = _week_start_from_date(inicio)

    try:
        adapted_user = user_to_adapter(current_user)
        pdf_bytes = await generate_weekly_pdf(inicio, company_id, db, adapted_user)
    except ImportError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.exception("Erro ao gerar PDF semanal")
        raise HTTPException(status_code=500, detail=f"Erro ao gerar PDF semanal: {str(e)}")

    num_semana = inicio.isocalendar()[1]
    file_name = f"METRICAS_SEMANA_{inicio.year}_{str(num_semana).zfill(2)}_{datetime.now().strftime('%Y%m%d')}.pdf"

    await _log_report_generation(
        db, current_user, "GERAR_PDF", "weekly",
        {"week_start": inicio.isoformat(), "company_id": str(company_id) if company_id else None},
        len(pdf_bytes), request,
    )

    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{file_name}"',
            "Content-Length": str(len(pdf_bytes)),
            "X-Report-Type": "weekly",
        },
    )


# ═══════════════════════════════════════════════════════════════════════
# 3. PDF MENSAL — Fase 2
# ═══════════════════════════════════════════════════════════════════════

@router.get("/month/pdf")
async def get_monthly_metrics_pdf(
    request: Request,
    month_start: str = Query(..., description="Primeiro dia do mes (YYYY-MM-DD)"),
    company_id: Optional[int] = Query(None),
    current_user: User = Depends(require_role(*ALL_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    """
    FASE 2 — Relatorio Mensal (placeholder).
    """
    try:
        inicio = _parse_date(month_start)
    except HTTPException:
        raise HTTPException(status_code=400, detail=f"month_start invalido: {month_start}")

    inicio = _month_start_from_date(inicio)

    try:
        adapted_user = user_to_adapter(current_user)
        pdf_bytes = await generate_monthly_pdf(inicio, company_id, db, adapted_user)
    except ImportError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.exception("Erro ao gerar PDF mensal")
        raise HTTPException(status_code=500, detail=f"Erro ao gerar PDF mensal: {str(e)}")

    file_name = f"RELATORIO_MENSAL_{inicio.year}_{str(inicio.month).zfill(2)}_{datetime.now().strftime('%Y%m%d')}.pdf"

    await _log_report_generation(
        db, current_user, "GERAR_PDF", "monthly",
        {"month_start": inicio.isoformat(), "company_id": str(company_id) if company_id else None},
        len(pdf_bytes), request,
    )

    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{file_name}"',
            "Content-Length": str(len(pdf_bytes)),
            "X-Report-Type": "monthly",
            "X-Report-Phase": "Fase 2",
        },
    )


# ═══════════════════════════════════════════════════════════════════════
# 4. EXCEL SEMANAL
# ═══════════════════════════════════════════════════════════════════════

@router.get("/week/excel")
async def get_weekly_metrics_excel(
    request: Request,
    week_start: str = Query(..., description="Segunda-feira da semana (YYYY-MM-DD)"),
    company_id: Optional[int] = Query(None),
    current_user: User = Depends(require_role(*STAFF_ROLES)),
    db: AsyncSession = Depends(get_db),
):
    """
    Exporta Metricas da Semana em Excel com 3 abas:
    Resumo, Consolidado, Registros Base.
    """
    try:
        inicio = _parse_date(week_start)
    except HTTPException:
        raise HTTPException(status_code=400, detail=f"week_start invalido: {week_start}")

    inicio = _week_start_from_date(inicio)
    week_end = inicio + timedelta(days=6)

    adapted_user = user_to_adapter(current_user)

    from app.services.metrics_service import (
        calculate_weekly_metrics,
        get_company_ranking,
        get_shift_distribution,
        get_top_behaviors,
    )
    from app.models import OfcRecord
    from sqlalchemy import select, and_

    try:
        metrics = await calculate_weekly_metrics(db, inicio, week_end, company_id, adapted_user)
        company_ranking = await get_company_ranking(db, inicio, week_end, company_id, adapted_user)
        shift_dist = await get_shift_distribution(db, inicio, week_end, company_id, adapted_user)
        behaviors = await get_top_behaviors(db, inicio, week_end, company_id, adapted_user)

        base_filters = [
            OfcRecord.is_deleted == False,
            OfcRecord.data_registro >= inicio,
            OfcRecord.data_registro <= week_end,
        ]
        if company_id:
            base_filters.append(OfcRecord.empresa_observada_id == company_id)
        elif current_user.role == "supervisor":
            base_filters.append(OfcRecord.empresa_observada_id == current_user.company_id)

        base_records_result = await db.execute(
            select(OfcRecord).where(and_(*base_filters))
            .order_by(OfcRecord.data_registro.desc(), OfcRecord.hora_registro.desc())
        )
        base_records = list(base_records_result.scalars().all())
    except Exception as e:
        logger.exception("Erro ao coletar dados para Excel")
        raise HTTPException(status_code=500, detail=f"Erro ao coletar dados: {str(e)}")

    safe_behaviors = [
        {"name": b["comportamento"], "count": b["count"]}
        for b in behaviors.get("seguros", [])
    ]
    unsafe_behaviors = [
        {"name": b["comportamento"], "count": b["count"]}
        for b in behaviors.get("desvios", [])
    ]

    num_semana = inicio.isocalendar()[1]

    excel_data = {
        "company_name": metrics.get("empresa_nome") or "Todas as Empresas",
        "generated_by": current_user.full_name,
        "ano": inicio.year,
        "semana": num_semana,
        "week_start": inicio.strftime("%d/%m/%Y"),
        "week_end": week_end.strftime("%d/%m/%Y"),
        "active_people": metrics["pessoas_ativas"],
        "planned": metrics["ofc_programadas"],
        "realized": metrics["ofc_realizadas"],
        "positive": metrics["ofc_positivas"],
        "negative": metrics["ofc_negativas"],
        "adherence": metrics["aderencia_percentual"],
        "pct_seguro": metrics["percentual_seguro"],
        "pct_desvio": metrics["percentual_desvio"],
        "active_users": metrics["usuarios_ativos"],
        "avg_ofc_per_user": metrics["media_ofc_usuario"],
        "top_safe": safe_behaviors,
        "top_unsafe": unsafe_behaviors,
        "consolidated": [
            {
                "company": r["empresa_nome"],
                "active_people": metrics.get("pessoas_ativas", 0),
                "planned": metrics["ofc_programadas"],
                "realized": r["total"],
                "positive": r["positivas"],
                "negative": r["negativas"],
                "adherence": r["aderencia"],
                "status": r.get("status", ""),
            }
            for r in company_ranking
        ],
        "base_records": [
            {
                "sequential_number": rec.codigo,
                "record_date": rec.data_registro.isoformat() if rec.data_registro else "-",
                "record_time": rec.hora_registro.isoformat() if rec.hora_registro else "-",
                "generated_by_name": rec.usuario_nome_snapshot,
                "company_name": rec.empresa_observada_outros or (rec.empresa_observada.nome if rec.empresa_observada else "-"),
                "observed_name": rec.nome_observado,
                "activity_observed": rec.atividade_observada,
                "location_observed": rec.local_observado,
                "shift": rec.turno,
                "type": rec.tipo_observacao,
                "behavior_observed": rec.comportamento_observado,
                "status": rec.status_registro,
            }
            for rec in base_records
        ],
    }

    try:
        xlsx_bytes = export_weekly_excel_bytes(excel_data)
    except ImportError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.exception("Erro ao gerar Excel semanal")
        raise HTTPException(status_code=500, detail=f"Erro ao gerar Excel: {str(e)}")

    file_name = f"METRICAS_SEMANA_{inicio.year}_{str(num_semana).zfill(2)}_{datetime.now().strftime('%Y%m%d')}.xlsx"

    await _log_report_generation(
        db, current_user, "EXPORTAR_EXCEL", "weekly",
        {"week_start": inicio.isoformat(), "company_id": str(company_id) if company_id else None},
        len(xlsx_bytes), request,
    )

    return StreamingResponse(
        iter([xlsx_bytes]),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="{file_name}"',
            "Content-Length": str(len(xlsx_bytes)),
            "X-Report-Type": "weekly_excel",
        },
    )
