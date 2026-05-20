"""
pdf_service.py — Servico principal de geracao de PDFs.
Orquestra a coleta de dados, geracao de graficos, renderizacao de templates
e conversao HTML-PDF via WeasyPrint.

Integracao completa: DB + WeasyPrint + matplotlib + Jinja2
"""
import os
import io
import uuid
import base64
import logging
from datetime import datetime, date
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional
from uuid import UUID

from jinja2 import Environment, FileSystemLoader, select_autoescape
from sqlalchemy.ext.asyncio import AsyncSession

from .chart_service import (
    generate_charts_for_weekly,
    generate_charts_for_monthly,
    generate_charts_for_company,
    ChartSet,
)

logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════════════════════
# Configuracao
# ═══════════════════════════════════════════════════════════════════════

TEMPLATES_DIR = Path(__file__).parent.parent / "templates"
REPORTS_DIR = Path(os.environ.get("REPORTS_DIR", "/app/reports"))
STATIC_DIR = Path(__file__).parent.parent / "static"
LOGO_PATH = STATIC_DIR / "logos" / "security-dynamics-logo.png"

# ═══════════════════════════════════════════════════════════════════════
# Logo Singleton (carregado 1x no modulo, lazy load)
# ═══════════════════════════════════════════════════════════════════════

_logo_cache: Optional[dict] = None
_logo_lock_initialized = False


def _init_logo() -> dict:
    global _logo_cache, _logo_lock_initialized
    if _logo_lock_initialized:
        return _logo_cache or {}
    _logo_lock_initialized = True

    if LOGO_PATH.exists():
        ext = LOGO_PATH.suffix.lower().replace(".", "")
        mime_map = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                     "svg": "image/svg+xml", "gif": "image/gif", "webp": "image/webp"}
        mime_type = mime_map.get(ext, f"image/{ext}")
        with open(LOGO_PATH, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("utf-8")
        _logo_cache = {"base64": b64, "mime": mime_type}
        logger.info(f"Logo carregado: {LOGO_PATH} ({len(b64)} chars base64)")
    else:
        _logo_cache = {"base64": "", "mime": ""}
        logger.warning(f"Logo nao encontrado em {LOGO_PATH}")
    return _logo_cache


def get_logo_base64() -> str:
    return _init_logo()["base64"]


def get_logo_mime() -> str:
    return _init_logo()["mime"]


# ═══════════════════════════════════════════════════════════════════════
# Jinja2 Environment
# ═══════════════════════════════════════════════════════════════════════

jinja_env = Environment(
    loader=FileSystemLoader(str(TEMPLATES_DIR)),
    autoescape=select_autoescape(["html"]),
    cache_size=50,
)


def format_date(value, fmt: str = "%d/%m/%Y"):
    if value is None:
        return "-"
    if isinstance(value, str):
        try:
            value = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            return value
    if isinstance(value, (datetime, date)):
        return value.strftime(fmt)
    return str(value)


def format_datetime(value, fmt: str = "%d/%m/%Y %H:%M"):
    return format_date(value, fmt)


def format_number(value, decimals: int = 1):
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:,.{decimals}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return str(value)


def format_percent(value, decimals: int = 1):
    if value is None:
        return "-"
    return f"{value:.{decimals}f}%"


jinja_env.filters["format_date"] = format_date
jinja_env.filters["format_datetime"] = format_datetime
jinja_env.filters["format_number"] = format_number
jinja_env.filters["format_percent"] = format_percent


# ═══════════════════════════════════════════════════════════════════════
# Contexto base (dados comuns a todos os relatorios)
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class BaseContext:
    generated_at: datetime = field(default_factory=datetime.now)

    def __post_init__(self):
        logo = _init_logo()
        self.logo_base64 = logo["base64"]
        self.logo_mime = logo["mime"]

    def to_dict(self) -> dict:
        return {
            "generated_at": self.generated_at,
            "generated_date": self.generated_at.strftime("%d/%m/%Y"),
            "generated_time": self.generated_at.strftime("%H:%M:%S"),
            "logo_base64": self.logo_base64,
            "logo_mime": self.logo_mime if self.logo_base64 else "",
        }


# ═══════════════════════════════════════════════════════════════════════
# Regras de status
# ═══════════════════════════════════════════════════════════════════════

STATUS_RULES = {
    "aderencia":      {"ok": (85, 100), "atencao": (70, 85),   "alerta": (0, 70)},
    "pessoas_ativas": {"ok": (30, 9999), "atencao": (15, 30),  "alerta": (0, 15)},
    "pct_seguro":     {"ok": (80, 100), "atencao": (60, 80),   "alerta": (0, 60)},
    "pct_desvio":     {"ok": (0, 15),   "atencao": (15, 30),   "alerta": (30, 100)},
    "media_ofc":      {"ok": (15, 9999), "atencao": (8, 15),   "alerta": (0, 8)},
}


def evaluate_status(indicator: str, value: float) -> str:
    rules = STATUS_RULES.get(indicator)
    if not rules:
        return ""
    lo, hi = rules["alerta"]
    if lo <= value < hi:
        return "ALERTA"
    lo, hi = rules["atencao"]
    if lo <= value < hi:
        return "ATENCAO"
    lo, hi = rules["ok"]
    if lo <= value <= hi:
        return "OK"
    return ""


def status_badge_html(status: str) -> str:
    if status == "OK":
        return '<span class="badge badge-ok">{}</span>'.format(status)
    elif status == "ATENCAO":
        return '<span class="badge badge-atencao">{}</span>'.format(status)
    elif status == "ALERTA":
        return '<span class="badge badge-alerta">{}</span>'.format(status)
    elif status in ("SEGURO", "POSITIVO"):
        return '<span class="badge badge-seguro">{}</span>'.format(status)
    elif status in ("INSEGURO", "NEGATIVO"):
        return '<span class="badge badge-inseguro">{}</span>'.format(status)
    elif status == "CANCELADO":
        return '<span class="badge badge-cancelado">{}</span>'.format(status)
    elif status == "EDITADO":
        return '<span class="badge badge-editado">{}</span>'.format(status)
    elif status == "ATIVO":
        return '<span class="badge badge-ok">{}</span>'.format(status)
    else:
        return status


# ═══════════════════════════════════════════════════════════════════════
# Nomes de arquivo padronizados
# ═══════════════════════════════════════════════════════════════════════

def gerar_nome_arquivo(tipo: str, parametros: dict) -> str:
    hoje = datetime.now().strftime("%Y%m%d")
    if tipo == "individual":
        codigo = parametros.get("codigo", parametros.get("ofc_id", "0000"))
        return f"OFC_INDIVIDUAL_{codigo}_{hoje}.pdf"
    elif tipo in ("weekly", "weekly_metrics"):
        ano = parametros.get("ano", datetime.now().year)
        semana = parametros.get("semana", 0)
        return f"METRICAS_SEMANA_{ano}_{str(semana).zfill(2)}_{hoje}.pdf"
    elif tipo == "monthly":
        ano = parametros.get("ano", datetime.now().year)
        mes = parametros.get("mes", datetime.now().month)
        return f"RELATORIO_MENSAL_{ano}_{str(mes).zfill(2)}_{hoje}.pdf"
    else:
        return f"RELATORIO_{tipo.upper()}_{hoje}.pdf"


def gerar_nome_arquivo_excel(tipo: str, parametros: dict) -> str:
    hoje = datetime.now().strftime("%Y%m%d")
    if tipo in ("weekly", "weekly_metrics"):
        ano = parametros.get("ano", datetime.now().year)
        semana = parametros.get("semana", 0)
        return f"METRICAS_SEMANA_{ano}_{str(semana).zfill(2)}_{hoje}.xlsx"
    else:
        return f"RELATORIO_{tipo.upper()}_{hoje}.xlsx"


# ═══════════════════════════════════════════════════════════════════════
# Conversao HTML -> PDF (WeasyPrint)
# ═══════════════════════════════════════════════════════════════════════

def _generate_pdf(html_content: str, report_type: str, report_id: str) -> Path:
    try:
        from weasyprint import HTML
    except ImportError:
        raise ImportError(
            "WeasyPrint nao esta instalado. Execute: pip install weasyprint"
        )
    now = datetime.now()
    output_dir = REPORTS_DIR / report_type / str(now.year) / f"{now.month:02d}"
    output_dir.mkdir(parents=True, exist_ok=True)
    file_path = output_dir / f"{report_id}.pdf"
    doc = HTML(string=html_content)
    doc.write_pdf(target=str(file_path))
    logger.info(f"PDF gerado: {file_path} ({file_path.stat().st_size} bytes)")
    return file_path


def _generate_pdf_bytes(html_content: str) -> bytes:
    try:
        from weasyprint import HTML
    except ImportError:
        raise ImportError(
            "WeasyPrint nao esta instalado. Execute: pip install weasyprint"
        )
    doc = HTML(string=html_content)
    buf = io.BytesIO()
    doc.write_pdf(target=buf)
    buf.seek(0)
    pdf_bytes = buf.getvalue()
    logger.info(f"PDF gerado em memoria: {len(pdf_bytes)} bytes")
    return pdf_bytes


# ═══════════════════════════════════════════════════════════════════════
# PDF INDIVIDUAL OFS — Pipeline completo com DB
# ═══════════════════════════════════════════════════════════════════════

async def generate_ofc_pdf(ofc_id: UUID, db: AsyncSession) -> bytes:
    """
    Gera PDF individual de um registro OFS/OFS.
    Pipeline: busca OFS no DB -> renderiza Jinja2 -> WeasyPrint -> bytes
    """
    from app.models.OFS import OFS, OFCEditLog
    from sqlalchemy import select

    result = await db.execute(
        select(OFS).where(OFS.id == ofc_id, OFS.is_deleted == False)
    )
    OFS = result.scalar_one_or_none()
    if not OFS:
        raise ValueError(f"Registro OFS/OFS nao encontrado: {ofc_id}")

    edit_logs_result = await db.execute(
        select(OFCEditLog)
        .where(OFCEditLog.ofc_id == ofc_id)
        .order_by(OFCEditLog.editado_em.desc())
    )
    edit_logs = list(edit_logs_result.scalars().all())

    base = BaseContext()
    report_id = f"ofc_{OFS.codigo or OFS.id}"

    template = jinja_env.get_template("reports/individual_ofc.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        OFS=OFS,
        edit_logs=edit_logs,
        status_badge=status_badge_html,
    )

    return _generate_pdf_bytes(html)


# ═══════════════════════════════════════════════════════════════════════
# PDF METRICAS DA SEMANA — Pipeline completo com DB
# ═══════════════════════════════════════════════════════════════════════

async def generate_weekly_pdf(
    week_start: date, company_id: Optional[UUID], db: AsyncSession, current_user
) -> bytes:
    """
    Gera PDF de Metricas da Semana.
    Pipeline: calcula metricas -> gera graficos matplotlib PNG -> renderiza
    Jinja2 -> WeasyPrint -> bytes
    """
    from .metrics_service import (
        calculate_weekly_metrics,
        get_company_ranking,
        get_shift_distribution,
        get_top_behaviors,
        get_weekly_evolution,
    )

    week_end = week_start + __import__("datetime").timedelta(days=6)

    metrics = await calculate_weekly_metrics(
        db, week_start, week_end, company_id, current_user
    )
    company_ranking = await get_company_ranking(
        db, week_start, week_end, company_id, current_user
    )
    shift_dist = await get_shift_distribution(
        db, week_start, week_end, company_id, current_user
    )
    behaviors = await get_top_behaviors(
        db, week_start, week_end, company_id, current_user
    )

    safe_behaviors = [
        {"name": b["comportamento"], "count": b["count"]}
        for b in behaviors.get("seguros", [])
    ]
    unsafe_behaviors = [
        {"name": b["comportamento"], "count": b["count"]}
        for b in behaviors.get("desvios", [])
    ]

    companies = [r["empresa_nome"] for r in company_ranking]
    company_counts = [r["total"] for r in company_ranking]

    shifts = [s["name"] for s in shift_dist]
    shift_counts = [s["value"] for s in shift_dist]

    week_realized = metrics["ofc_realizadas"]
    week_positive = metrics["ofc_positivas"]
    week_negative = metrics["ofc_negativas"]
    aderencia = metrics["aderencia_percentual"]
    pct_seguro = metrics["percentual_seguro"]
    pct_desvio = metrics["percentual_desvio"]

    chart_data = {
        "planned": metrics["ofc_programadas"],
        "realized": week_realized,
        "positive": week_positive,
        "negative": week_negative,
        "companies": companies,
        "company_counts": company_counts,
        "shifts": shifts,
        "shift_counts": shift_counts,
        "top_safe": safe_behaviors,
        "top_unsafe": unsafe_behaviors,
    }

    charts = generate_charts_for_weekly(chart_data)
    charts_b64 = charts.to_base64()

    consolidated = [
        {
            "company": r["empresa_nome"],
            "active_people": metrics.get("pessoas_ativas", 0),
            "planned": metrics["ofc_programadas"],
            "realized": r["total"],
            "positive": r["positivas"],
            "negative": r["negativas"],
            "adherence": r["aderencia"],
            "status": evaluate_status("aderencia", r["aderencia"]),
        }
        for r in company_ranking
    ]

    indicators = {
        "pessoas_ativas": metrics["pessoas_ativas"],
        "ofc_programadas": metrics["ofc_programadas"],
        "ofc_realizadas": week_realized,
        "positivas": week_positive,
        "negativas": week_negative,
        "aderencia": aderencia,
        "pct_seguro": pct_seguro,
        "pct_desvio": pct_desvio,
        "usuarios_ativos": metrics["usuarios_ativos"],
        "media_ofc_por_usuario": metrics["media_ofc_usuario"],
        "status_aderencia": evaluate_status("aderencia", aderencia),
    }

    totals_row = None
    if consolidated:
        tot_realized = sum(r["realized"] for r in consolidated)
        tot_planned = sum(r.get("planned", 0) for r in consolidated)
        totals_row = {
            "active_people": sum(r.get("active_people", 0) for r in consolidated),
            "planned": tot_planned,
            "realized": tot_realized,
            "positive": sum(r["positive"] for r in consolidated),
            "negative": sum(r["negative"] for r in consolidated),
            "adherence": (tot_realized / max(tot_planned, 1) * 100),
            "status": evaluate_status("aderencia", (tot_realized / max(tot_planned, 1) * 100)),
        }

    ano = week_start.year
    num_semana = week_start.isocalendar()[1]

    base = BaseContext()
    report_id = f"metrics_{week_start.isoformat()}"

    template = jinja_env.get_template("reports/weekly_metrics.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        company_name=metrics.get("empresa_nome") or "Todas as Empresas",
        generated_by=current_user.nome,
        week_label=f"Semana {num_semana}/{ano}",
        week_start=week_start.strftime("%d/%m/%Y"),
        week_end=week_end.strftime("%d/%m/%Y"),
        filters=None,
        indicators=indicators,
        charts=charts_b64,
        consolidated=consolidated,
        totals_row=totals_row,
        safe_behaviors=safe_behaviors,
        unsafe_behaviors=unsafe_behaviors,
        show_signature=True,
        manager_name=current_user.nome,
        manager_role=current_user.perfil,
        status_badge=status_badge_html,
    )

    return _generate_pdf_bytes(html)


# ═══════════════════════════════════════════════════════════════════════
# PDF MENSAL — Fase 2 (MVP: apenas metodo stub com indicacao)
# ═══════════════════════════════════════════════════════════════════════

async def generate_monthly_pdf(
    month_start: date, company_id: Optional[UUID], db: AsyncSession, current_user
) -> bytes:
    """
    FASE 2 — Relatorio Mensal.
    Atualmente retorna um PDF placeholder indicando que esta na Fase 2.
    """
    report_id = f"monthly_{month_start.isoformat()}"
    base = BaseContext()

    template = jinja_env.get_template("reports/monthly_report.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        company_name="Security Dynamics Ltda.",
        generated_by=current_user.nome if current_user else "Sistema",
        month_label=month_start.strftime("%B/%Y"),
        week_data=[],
        summary={
            "total_realized": 0,
            "total_positive": 0,
            "total_negative": 0,
            "avg_adherence": 0.0,
            "avg_week_realized": 0.0,
            "trend_realized": "->",
            "trend_realized_class": "trend-stable",
            "trend_adherence": "->",
            "trend_adherence_class": "trend-stable",
        },
        charts={},
        previous_month_label="",
        status_badge=status_badge_html,
    )

    return _generate_pdf_bytes(html)


# ═══════════════════════════════════════════════════════════════════════
# Builders por tipo de relatorio (legados, usados pelo reports_router antigo)
# ═══════════════════════════════════════════════════════════════════════

def build_weekly_report(data: dict) -> Path:
    report_id = data.get("report_id", str(uuid.uuid4()))
    base = BaseContext()
    charts = generate_charts_for_weekly(data)
    charts_b64 = charts.to_base64()

    indicators = [
        {"name": "Pessoas Ativas",        "value": data.get("active_people", 50),    "fmt": "int",
         "status": evaluate_status("pessoas_ativas", data.get("active_people", 50))},
        {"name": "OFS Programadas",        "value": data.get("planned", 250),         "fmt": "int",  "status": ""},
        {"name": "OFS Realizadas",         "value": data.get("realized", 230),        "fmt": "int",  "status": ""},
        {"name": "Aderencia %",            "value": data.get("adherence", 92.0),      "fmt": "pct",
         "status": evaluate_status("aderencia", data.get("adherence", 92.0))},
        {"name": "Positivas",              "value": data.get("positive", 195),        "fmt": "int",
         "status": evaluate_status("pct_seguro", data.get("positive", 195) / max(data.get("realized", 230), 1) * 100)},
        {"name": "Negativas",              "value": data.get("negative", 35),         "fmt": "int",
         "status": evaluate_status("pct_desvio", data.get("negative", 35) / max(data.get("realized", 230), 1) * 100)},
        {"name": "% Seguro",               "value": data.get("pct_seguro", 84.8),     "fmt": "pct",
         "status": evaluate_status("pct_seguro", data.get("pct_seguro", 84.8))},
        {"name": "% Desvio",               "value": data.get("pct_desvio", 15.2),     "fmt": "pct",
         "status": evaluate_status("pct_desvio", data.get("pct_desvio", 15.2))},
        {"name": "Usuarios Ativos",        "value": data.get("active_users", 12),     "fmt": "int",  "status": ""},
        {"name": "Media OFS por Usuario",  "value": data.get("avg_ofc_per_user", 19.2), "fmt": "float",
         "status": evaluate_status("media_ofc", data.get("avg_ofc_per_user", 19.2))},
    ]

    safe_behaviors = data.get("top_safe", [])
    unsafe_behaviors = data.get("top_unsafe", [])

    template = jinja_env.get_template("reports/weekly_report.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        company_name=data.get("company_name", "Security Dynamics Ltda."),
        generated_by=data.get("generated_by", ""),
        week_start=data.get("week_start", ""),
        week_end=data.get("week_end", ""),
        indicators=indicators,
        charts=charts_b64,
        safe_behaviors=safe_behaviors,
        unsafe_behaviors=unsafe_behaviors,
        show_signature=data.get("show_signature", True),
        manager_name=data.get("manager_name", ""),
        manager_role=data.get("manager_role", ""),
        status_badge=status_badge_html,
    )
    return _generate_pdf(html, "weekly", report_id)


def build_weekly_metrics_report(data: dict) -> Path:
    report_id = data.get("report_id", str(uuid.uuid4()))
    base = BaseContext()
    charts = generate_charts_for_weekly(data)
    charts_b64 = charts.to_base64()

    realized = data.get("realized", 0) or 0
    positive = data.get("positive", 0) or 0
    negative = data.get("negative", 0) or 0
    adherence = data.get("adherence", 0.0) or 0.0
    pct_seguro = data.get("pct_seguro", 0.0) or 0.0
    pct_desvio = data.get("pct_desvio", 0.0) or 0.0

    indicators = {
        "pessoas_ativas": data.get("active_people", 0),
        "ofc_programadas": data.get("planned", 0),
        "ofc_realizadas": realized,
        "positivas": positive,
        "negativas": negative,
        "aderencia": adherence,
        "pct_seguro": pct_seguro,
        "pct_desvio": pct_desvio,
        "usuarios_ativos": data.get("active_users", 0),
        "media_ofc_por_usuario": data.get("avg_ofc_per_user", 0),
        "status_aderencia": evaluate_status("aderencia", adherence),
    }

    consolidated = data.get("consolidated", [])
    totals_row = None
    if consolidated:
        totals_row = {
            "active_people": sum(r.get("active_people", 0) for r in consolidated),
            "planned": sum(r.get("planned", 0) for r in consolidated),
            "realized": sum(r.get("realized", 0) for r in consolidated),
            "positive": sum(r.get("positive", 0) for r in consolidated),
            "negative": sum(r.get("negative", 0) for r in consolidated),
            "adherence": (sum(r.get("realized", 0) for r in consolidated)
                          / max(sum(r.get("planned", 0) for r in consolidated), 1) * 100),
            "status": evaluate_status("aderencia",
                (sum(r.get("realized", 0) for r in consolidated)
                 / max(sum(r.get("planned", 0) for r in consolidated), 1) * 100)),
        }

    filters_parts = []
    if data.get("contract_name"):
        filters_parts.append(f"Contrato: {data['contract_name']}")
    if data.get("shift_filter"):
        filters_parts.append(f"Turno: {data['shift_filter']}")
    filters_text = " | ".join(filters_parts) if filters_parts else None

    template = jinja_env.get_template("reports/weekly_metrics.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        company_name=data.get("company_name", "Security Dynamics Ltda."),
        generated_by=data.get("generated_by", ""),
        week_label=data.get("week_label", f"Semana {data.get('semana', '-')}/{data.get('ano', '-')}"),
        week_start=data.get("week_start", ""),
        week_end=data.get("week_end", ""),
        filters=filters_text,
        indicators=indicators,
        charts=charts_b64,
        consolidated=consolidated,
        totals_row=totals_row,
        safe_behaviors=data.get("top_safe", []),
        unsafe_behaviors=data.get("top_unsafe", []),
        show_signature=data.get("show_signature", True),
        manager_name=data.get("manager_name", ""),
        manager_role=data.get("manager_role", ""),
        status_badge=status_badge_html,
    )
    return _generate_pdf(html, "weekly_metrics", report_id)


def build_individual_report(data: dict) -> Path:
    report_id = data.get("report_id", str(uuid.uuid4()))
    base = BaseContext()
    ofc_records = data.get("ofc_records", [])
    template = jinja_env.get_template("reports/individual_report.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        ofc_records=ofc_records,
        status_badge=status_badge_html,
        generated_by=data.get("generated_by", ""),
        is_compact=data.get("compact", False),
    )
    return _generate_pdf(html, "individual", report_id)


def build_monthly_report(data: dict) -> Path:
    report_id = data.get("report_id", str(uuid.uuid4()))
    base = BaseContext()
    charts = generate_charts_for_monthly(data)
    charts_b64 = charts.to_base64()

    week_labels = data.get("weeks", [f"Semana {i+1}" for i in range(4)])
    week_data = []
    for i, label in enumerate(week_labels):
        week_data.append({
            "label": label,
            "realized": data.get("week_realized", [0]*4)[i] if i < len(data.get("week_realized", [])) else 0,
            "positive": data.get("week_positive", [0]*4)[i] if i < len(data.get("week_positive", [])) else 0,
            "negative": data.get("week_negative", [0]*4)[i] if i < len(data.get("week_negative", [])) else 0,
            "planned": data.get("week_planned", [0]*4)[i] if i < len(data.get("week_planned", [])) else 0,
            "adherence": data.get("week_adherence", [0.0]*4)[i] if i < len(data.get("week_adherence", [])) else 0.0,
        })

    total_realized = sum(w["realized"] for w in week_data)
    total_positive = sum(w["positive"] for w in week_data)
    total_negative = sum(w["negative"] for w in week_data)
    avg_adherence = sum(w["adherence"] for w in week_data) / max(len(week_data), 1)

    previous_data = data.get("previous_month", {})
    prev_realized = previous_data.get("realized", 0)
    prev_adherence = previous_data.get("adherence", 0.0)

    def trend(current, previous):
        if previous == 0:
            return ("-", "trend-up") if current > 0 else ("-", "trend-stable")
        variation = ((current - previous) / previous) * 100
        if variation > 3:
            return "-", "trend-up"
        elif variation < -3:
            return "-", "trend-down"
        return "-", "trend-stable"

    trend_realized, trend_realized_class = trend(total_realized, prev_realized)
    trend_adherence, trend_adherence_class = trend(avg_adherence, prev_adherence)

    summary = {
        "total_realized": total_realized,
        "total_positive": total_positive,
        "total_negative": total_negative,
        "avg_adherence": round(avg_adherence, 1),
        "avg_week_realized": round(total_realized / max(len(week_data), 1), 1),
        "trend_realized": trend_realized,
        "trend_realized_class": trend_realized_class,
        "trend_adherence": trend_adherence,
        "trend_adherence_class": trend_adherence_class,
    }

    template = jinja_env.get_template("reports/monthly_report.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        company_name=data.get("company_name", "Security Dynamics Ltda."),
        generated_by=data.get("generated_by", ""),
        month_label=data.get("month_label", datetime.now().strftime("%B/%Y")),
        week_data=week_data,
        summary=summary,
        charts=charts_b64,
        previous_month_label=data.get("previous_month_label", ""),
        status_badge=status_badge_html,
    )
    return _generate_pdf(html, "monthly", report_id)


def build_company_report(data: dict) -> Path:
    report_id = data.get("report_id", str(uuid.uuid4()))
    base = BaseContext()
    charts = generate_charts_for_company(data)
    charts_b64 = charts.to_base64()

    ofc_records = data.get("ofc_records", [])
    positive_OFSS = [o for o in ofc_records if o.get("type", "").upper() in ("POSITIVO", "SEGURO", "POSITIVE")]
    negative_OFSS = [o for o in ofc_records if o.get("type", "").upper() in ("NEGATIVO", "INSEGURO", "NEGATIVE")]
    cancelled_OFSS = [o for o in ofc_records if o.get("status", "").upper() == "CANCELADO"]

    template = jinja_env.get_template("reports/company_report.html")
    html = template.render(
        **base.to_dict(),
        report_id=report_id,
        company_name=data.get("company_name", "Security Dynamics Ltda."),
        generated_by=data.get("generated_by", ""),
        start_date=data.get("start_date", ""),
        end_date=data.get("end_date", ""),
        summary={
            "planned": data.get("planned", 0),
            "realized": data.get("realized", 0),
            "positive": len(positive_OFSS),
            "negative": len(negative_OFSS),
        },
        positive_OFSS=positive_OFSS,
        negative_OFSS=negative_OFSS,
        cancelled_OFSS=cancelled_OFSS,
        charts=charts_b64,
        status_badge=status_badge_html,
        format_date=format_date,
    )
    return _generate_pdf(html, "company", report_id)


# ═══════════════════════════════════════════════════════════════════════
# Interface publica unificada (legada)
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class ReportResult:
    report_id: str
    file_path: Path
    file_name: str
    file_size: int
    generated_at: datetime


def generate_report(report_type: str, data: dict) -> ReportResult:
    builders = {
        "weekly":         build_weekly_report,
        "weekly_metrics": build_weekly_metrics_report,
        "individual":     build_individual_report,
        "monthly":        build_monthly_report,
        "company":        build_company_report,
    }
    builder = builders.get(report_type)
    if not builder:
        raise ValueError(f"Tipo de relatorio invalido: {report_type}. Opcoes: {list(builders.keys())}")
    file_path = builder(data)
    now = datetime.now()
    return ReportResult(
        report_id=data.get("report_id", file_path.stem),
        file_path=file_path,
        file_name=file_path.name,
        file_size=file_path.stat().st_size,
        generated_at=now,
    )
