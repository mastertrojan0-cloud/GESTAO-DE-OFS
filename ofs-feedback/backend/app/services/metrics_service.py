import logging
import threading
from datetime import datetime, timedelta, date, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, func, and_, case, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import literal_column

from app.models.ofs_record import OfsRecord
from app.models.user import User
from app.models.company import Company
from app.models.target import Target

logger = logging.getLogger(__name__)

_METRICS_CACHE: dict[str, tuple[float, object]] = {}
_CACHE_LOCK = threading.Lock()
CACHE_TTL_SECONDS = 300


def _cache_key(*args) -> str:
    return "|".join(str(a) for a in args)


def _cache_get(key: str) -> object | None:
    with _CACHE_LOCK:
        entry = _METRICS_CACHE.get(key)
        if entry is None:
            return None
        timestamp, value = entry
        if datetime.now(timezone.utc).timestamp() - timestamp > CACHE_TTL_SECONDS:
            del _METRICS_CACHE[key]
            return None
        return value


def _cache_set(key: str, value: object) -> None:
    with _CACHE_LOCK:
        _METRICS_CACHE[key] = (datetime.now(timezone.utc).timestamp(), value)
        if len(_METRICS_CACHE) > 200:
            oldest = min(_METRICS_CACHE, key=lambda k: _METRICS_CACHE[k][0])
            del _METRICS_CACHE[oldest]


def invalidate_metrics_cache() -> None:
    with _CACHE_LOCK:
        _METRICS_CACHE.clear()
        logger.info("Cache de metricas invalidado.")


def _apply_scope_filters(user: User) -> list:
    filters = [OfsRecord.is_deleted == False, OfsRecord.status_registro != "Cancelado"]
    if user.role == "observador":
        filters.append(OfsRecord.criado_por == user.id)
    elif user.role == "supervisor":
        filters.append(OfsRecord.empresa_observada_id == user.company_id)
    return filters


STATUS_RULES = {
    "aderencia": {"ok": (85, 100), "atencao": (70, 85), "alerta": (0, 70)},
    "pct_seguro": {"ok": (80, 100), "atencao": (60, 80), "alerta": (0, 60)},
    "pct_negativo": {"ok": (0, 15), "atencao": (15, 30), "alerta": (30, 100)},
    "media_ofs": {"ok": (15, 9999), "atencao": (8, 15), "alerta": (0, 8)},
}


def _evaluate_indicator_status(indicator: str, value: float) -> str:
    rules = STATUS_RULES.get(indicator)
    if not rules:
        return ""
    for status_name in ("alerta", "atencao", "ok"):
        lo, hi = rules[status_name]
        if lo <= value < hi or (status_name == "ok" and lo <= value <= hi):
            if status_name == "alerta":
                return "ALERTA"
            elif status_name == "atencao":
                return "ATENCAO"
            else:
                return "OK"
    return ""


def _evaluate_week_status(aderencia: float, pct_seguro: float, pct_negativo: float, media: float) -> str:
    statuses = [
        _evaluate_indicator_status("aderencia", aderencia),
        _evaluate_indicator_status("pct_seguro", pct_seguro),
        _evaluate_indicator_status("pct_negativo", pct_negativo),
        _evaluate_indicator_status("media_ofs", media),
    ]
    if "ALERTA" in statuses:
        return "ALERTA"
    if "ATENCAO" in statuses:
        return "ATENCAO"
    return "OK"


async def calculate_weekly_metrics(
    db: AsyncSession,
    year: int,
    week: int,
    company_id: Optional[int] = None,
    current_user: Optional[User] = None,
) -> dict:
    cache_key = _cache_key("weekly", year, week, company_id, current_user.id if current_user else "anon")
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    from datetime import date as dt_date
    jan1 = dt_date(year, 1, 1)
    jan1_weekday = jan1.weekday()
    if jan1_weekday <= 3:
        week1_start = jan1 - timedelta(days=jan1_weekday)
    else:
        week1_start = jan1 + timedelta(days=7 - jan1_weekday)
    data_inicio = week1_start + timedelta(weeks=week - 1)
    data_fim = data_inicio + timedelta(days=6)

    filters = [OfsRecord.is_deleted == False, OfsRecord.status_registro != "Cancelado"]

    if current_user:
        if current_user.role == "observador":
            filters.append(OfsRecord.criado_por == current_user.id)
        elif current_user.role == "supervisor":
            filters.append(OfsRecord.empresa_observada_id == current_user.company_id)

    if company_id:
        filters.append(OfsRecord.empresa_observada_id == company_id)

    filters.append(OfsRecord.data_registro >= data_inicio)
    filters.append(OfsRecord.data_registro <= data_fim)

    total_realizadas = (await db.execute(
        select(func.count(OfsRecord.id)).where(and_(*filters))
    )).scalar() or 0

    positivas = (await db.execute(
        select(func.count(OfsRecord.id)).where(
            and_(*filters, OfsRecord.tipo_observacao == "Positivo (Seguro)")
        )
    )).scalar() or 0

    negativas = (await db.execute(
        select(func.count(OfsRecord.id)).where(
            and_(*filters, OfsRecord.tipo_observacao == "Negativo (Inseguro)")
        )
    )).scalar() or 0

    usuarios_ativos = (await db.execute(
        select(func.count(func.distinct(OfsRecord.criado_por))).where(and_(*filters))
    )).scalar() or 0

    effective_company_id = company_id or (current_user.company_id if current_user else None)
    target_result = None
    if effective_company_id:
        target_result = (await db.execute(
            select(Target)
            .where(
                Target.company_id == effective_company_id,
                Target.week_start <= data_inicio,
                Target.is_active == True,
            )
            .order_by(Target.week_start.desc())
            .limit(1)
        )).scalar_one_or_none()

    if target_result:
        pessoas_ativas = target_result.active_people
        ofs_programadas = target_result.active_people * target_result.weekly_target
    else:
        pessoas_ativas = max(usuarios_ativos, 1)
        ofs_programadas = total_realizadas

    aderencia = (total_realizadas / ofs_programadas * 100) if ofs_programadas > 0 else 100.0
    pct_seguro = (positivas / total_realizadas * 100) if total_realizadas > 0 else 0.0
    pct_negativo = (negativas / total_realizadas * 100) if total_realizadas > 0 else 0.0
    media_ofs_usuario = (total_realizadas / usuarios_ativos) if usuarios_ativos > 0 else 0.0

    status = _evaluate_week_status(aderencia, pct_seguro, pct_negativo, media_ofs_usuario)

    empresa_nome = None
    if effective_company_id:
        emp = await db.get(Company, effective_company_id)
        empresa_nome = emp.name if emp else None

    result = {
        "ano": year,
        "semana": week,
        "data_inicio": data_inicio,
        "data_fim": data_fim,
        "empresa_id": effective_company_id,
        "empresa_nome": empresa_nome,
        "pessoas_ativas": pessoas_ativas,
        "ofc_programadas": ofs_programadas,
        "ofc_realizadas": total_realizadas,
        "ofc_positivas": positivas,
        "ofc_negativas": negativas,
        "aderencia_percentual": round(aderencia, 1),
        "percentual_seguro": round(pct_seguro, 1),
        "percentual_negativo": round(pct_negativo, 1),
        "percentual_desvio": round(pct_negativo, 1),  # legacy alias
        "usuarios_ativos": usuarios_ativos,
        "media_ofc_usuario": round(media_ofs_usuario, 1),
        "status": status,
        "gerado_em": datetime.now(timezone.utc).isoformat(),
        "gerado_por": current_user.full_name if current_user else "Sistema",
    }

    _cache_set(cache_key, result)
    return result


async def get_evolution(
    db: AsyncSession,
    year: int,
    start_week: int,
    weeks: int,
    company_id: Optional[int] = None,
    current_user: Optional[User] = None,
) -> list[dict]:
    cache_key = _cache_key("evolution", year, start_week, weeks, company_id, current_user.id if current_user else "anon")
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    evolution = []
    for w in range(start_week, start_week + weeks):
        metrics = await calculate_weekly_metrics(db, year, w, company_id, current_user)
        evolution.append({
            "semana": f"S{w} ({metrics['data_inicio']} - {metrics['data_fim']})",
            "programado": metrics["ofc_programadas"],
            "realizado": metrics["ofc_realizadas"],
            "positivas": metrics["ofc_positivas"],
            "negativas": metrics["ofc_negativas"],
            "aderencia": metrics["aderencia_percentual"],
        })

    _cache_set(cache_key, evolution)
    return evolution


async def get_ranking(
    db: AsyncSession,
    year: int,
    week: int,
    current_user: Optional[User] = None,
) -> list[dict]:
    cache_key = _cache_key("company_ranking", year, week, current_user.id if current_user else "anon")
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    from datetime import date as dt_date
    jan1 = dt_date(year, 1, 1)
    jan1_weekday = jan1.weekday()
    if jan1_weekday <= 3:
        week1_start = jan1 - timedelta(days=jan1_weekday)
    else:
        week1_start = jan1 + timedelta(days=7 - jan1_weekday)
    data_inicio = week1_start + timedelta(weeks=week - 1)
    data_fim = data_inicio + timedelta(days=6)

    filters = [OfsRecord.is_deleted == False, OfsRecord.status_registro != "Cancelado"]
    if current_user:
        if current_user.role == "observador":
            filters.append(OfsRecord.criado_por == current_user.id)
        elif current_user.role == "supervisor":
            filters.append(OfsRecord.empresa_observada_id == current_user.company_id)
    filters.append(OfsRecord.data_registro >= data_inicio)
    filters.append(OfsRecord.data_registro <= data_fim)

    query = (
        select(
            OfsRecord.empresa_observada_id,
            func.count(OfsRecord.id).label("total"),
            func.count().filter(OfsRecord.tipo_observacao == "Positivo (Seguro)").label("positivas"),
            func.count().filter(OfsRecord.tipo_observacao == "Negativo (Inseguro)").label("negativas"),
        )
        .where(and_(*filters))
        .group_by(OfsRecord.empresa_observada_id)
        .order_by(literal_column("total").desc())
    )

    rows = (await db.execute(query)).all()

    ranking = []
    for row in rows:
        emp_nome = None
        if row.empresa_observada_id:
            emp = await db.get(Company, row.empresa_observada_id)
            emp_nome = emp.name if emp else "Outros"
        else:
            emp_nome = "Outros"

        total = row.total or 0
        pos = row.positivas or 0
        neg = row.negativas or 0
        pct_seguro = round((pos / total * 100) if total > 0 else 0, 1)

        ranking.append({
            "empresa_id": row.empresa_observada_id or 0,
            "empresa_nome": emp_nome,
            "total": total,
            "positivas": pos,
            "negativas": neg,
            "percentual_seguro": pct_seguro,
        })

    _cache_set(cache_key, ranking)
    return ranking


async def get_shift_distribution(
    db: AsyncSession,
    year: int,
    week: int,
    company_id: Optional[int] = None,
    current_user: Optional[User] = None,
) -> list[dict]:
    cache_key = _cache_key("shift_dist", year, week, company_id, current_user.id if current_user else "anon")
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    from datetime import date as dt_date
    jan1 = dt_date(year, 1, 1)
    jan1_weekday = jan1.weekday()
    if jan1_weekday <= 3:
        week1_start = jan1 - timedelta(days=jan1_weekday)
    else:
        week1_start = jan1 + timedelta(days=7 - jan1_weekday)
    data_inicio = week1_start + timedelta(weeks=week - 1)
    data_fim = data_inicio + timedelta(days=6)

    filters = [OfsRecord.is_deleted == False, OfsRecord.status_registro != "Cancelado"]
    if current_user:
        if current_user.role == "observador":
            filters.append(OfsRecord.criado_por == current_user.id)
        elif current_user.role == "supervisor":
            filters.append(OfsRecord.empresa_observada_id == current_user.company_id)
    if company_id:
        filters.append(OfsRecord.empresa_observada_id == company_id)
    filters.append(OfsRecord.data_registro >= data_inicio)
    filters.append(OfsRecord.data_registro <= data_fim)

    query = (
        select(OfsRecord.turno, func.count(OfsRecord.id).label("cnt"))
        .where(and_(*filters))
        .group_by(OfsRecord.turno)
        .order_by(literal_column("cnt").desc())
    )
    rows = (await db.execute(query)).all()

    SHIFT_COLORS = {"ADM": "#8B5CF6", "1": "#3B82F6", "2": "#22C55E", "3": "#F97316",
                    "Diurno": "#3B82F6", "Noturno": "#6366F1", "Administrativo": "#8B5CF6"}
    SHIFT_NAMES = {"ADM": "Administrativo", "1": "Turno 1", "2": "Turno 2", "3": "Turno 3"}

    result = [
        {
            "name": SHIFT_NAMES.get(r.turno, r.turno),
            "value": r.cnt,
            "color": SHIFT_COLORS.get(r.turno, "#CCCCCC"),
        }
        for r in rows
    ]
    _cache_set(cache_key, result)
    return result


async def get_top_behaviors(
    db: AsyncSession,
    year: int,
    week: int,
    company_id: Optional[int] = None,
    current_user: Optional[User] = None,
    limit: int = 5,
) -> dict:
    cache_key = _cache_key("top_behaviors", year, week, company_id, current_user.id if current_user else "anon", limit)
    cached = _cache_get(cache_key)
    if cached is not None:
        return cached

    from datetime import date as dt_date
    jan1 = dt_date(year, 1, 1)
    jan1_weekday = jan1.weekday()
    if jan1_weekday <= 3:
        week1_start = jan1 - timedelta(days=jan1_weekday)
    else:
        week1_start = jan1 + timedelta(days=7 - jan1_weekday)
    data_inicio = week1_start + timedelta(weeks=week - 1)
    data_fim = data_inicio + timedelta(days=6)

    filters = [OfsRecord.is_deleted == False, OfsRecord.status_registro != "Cancelado"]
    if current_user:
        if current_user.role == "observador":
            filters.append(OfsRecord.criado_por == current_user.id)
        elif current_user.role == "supervisor":
            filters.append(OfsRecord.empresa_observada_id == current_user.company_id)
    if company_id:
        filters.append(OfsRecord.empresa_observada_id == company_id)
    filters.append(OfsRecord.data_registro >= data_inicio)
    filters.append(OfsRecord.data_registro <= data_fim)

    seguros_q = (
        select(OfsRecord.comportamento_observado, func.count(OfsRecord.id).label("cnt"))
        .where(and_(*filters, OfsRecord.tipo_observacao == "Positivo (Seguro)"))
        .group_by(OfsRecord.comportamento_observado)
        .order_by(literal_column("cnt").desc())
        .limit(limit)
    )
    seguros_rows = (await db.execute(seguros_q)).all()

    negativos_q = (
        select(OfsRecord.comportamento_observado, func.count(OfsRecord.id).label("cnt"))
        .where(and_(*filters, OfsRecord.tipo_observacao == "Negativo (Inseguro)"))
        .group_by(OfsRecord.comportamento_observado)
        .order_by(literal_column("cnt").desc())
        .limit(limit)
    )
    negativos_rows = (await db.execute(negativos_q)).all()

    result = {
        "seguros": [{"comportamento": r.comportamento_observado, "count": r.cnt} for r in seguros_rows],
        "negativos": [{"comportamento": r.comportamento_observado, "count": r.cnt} for r in negativos_rows],
        # Legacy alias
        "desvios": [{"comportamento": r.comportamento_observado, "count": r.cnt} for r in negativos_rows],
    }
    _cache_set(cache_key, result)
    return result


# ============================================================
# Aliases de compatibilidade (legacy API)
# ============================================================
get_company_ranking = get_ranking

get_weekly_evolution = get_evolution


async def get_user_ranking(*args, **kwargs):
    """Placeholder — user ranking via dashboard endpoint."""
    return {"ranking": []}


async def get_programmed_vs_realized(*args, **kwargs):
    """Placeholder — programmed vs realized chart data."""
    return {"chart": [
        {"label": "Programado", "value": 0, "extra": None},
        {"label": "Realizado", "value": 0, "extra": None},
    ]}


async def get_positive_vs_negative(*args, **kwargs):
    """Placeholder — positive vs negative chart data."""
    return {"chart": [
        {"name": "Positivo (Seguro)", "value": 0, "color": "#22C55E"},
        {"name": "Negativo (Inseguro)", "value": 0, "color": "#EF4444"},
    ], "total": 0}
