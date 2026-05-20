"""
chart_service.py — Geracao de graficos com matplotlib para relatorios PDF.
Todos os graficos sao renderizados em memoria (BytesIO) e retornados como PNG bytes.
Usa ProcessPoolExecutor para paralelismo com fallback para ThreadPoolExecutor.
"""

import io
import hashlib
import os
import time
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from functools import partial

import matplotlib
matplotlib.use("Agg")

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
from matplotlib.figure import Figure
from PIL import Image

# ═══════════════════════════════════════════════════════════════════════
# Configuracao visual global
# ═══════════════════════════════════════════════════════════════════════

plt.rcParams.update({
    "font.family": "sans-serif",
    "font.sans-serif": ["DejaVu Sans", "Arial", "Helvetica"],
    "font.size": 10,
    "axes.titlesize": 12,
    "axes.titleweight": "bold",
    "axes.labelcolor": "#1A1A1A",
    "axes.edgecolor": "#CCCCCC",
    "axes.grid": True,
    "axes.grid.axis": "y",
    "grid.alpha": 0.3,
    "grid.color": "#CCCCCC",
    "xtick.color": "#666666",
    "ytick.color": "#666666",
    "figure.facecolor": "#FFFFFF",
    "axes.facecolor": "#FFFFFF",
    "savefig.dpi": 150,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.1,
})

CORPORATE_RED = "#CC0000"
CORPORATE_BLACK = "#1A1A1A"
CORPORATE_GRAY = "#F5F5F5"
CORPORATE_DARK_GRAY = "#666666"
GREEN = "#22C55E"
YELLOW = "#EAB308"
RED = "#EF4444"
BLUE = "#3B82F6"

COLOR_PALETTE = [CORPORATE_RED, BLUE, GREEN, YELLOW, "#8B5CF6", "#F97316", "#14B8A6", "#EC4899"]

# ═══════════════════════════════════════════════════════════════════════
# Executor para paralelismo: ProcessPoolExecutor preferido, fallback Thread
# ═══════════════════════════════════════════════════════════════════════

_MAX_CHART_WORKERS = min(os.cpu_count() or 2, 4)

try:
    if os.name == "nt":
        chart_executor = ThreadPoolExecutor(max_workers=_MAX_CHART_WORKERS, thread_name_prefix="chart")
    else:
        chart_executor = ProcessPoolExecutor(max_workers=_MAX_CHART_WORKERS)
except Exception:
    chart_executor = ThreadPoolExecutor(max_workers=_MAX_CHART_WORKERS, thread_name_prefix="chart")

# ═══════════════════════════════════════════════════════════════════════
# Cache de graficos em disco
# ═══════════════════════════════════════════════════════════════════════

CHART_CACHE_DIR = Path(os.environ.get("CHART_CACHE_DIR", "/tmp/charts_cache"))
CHART_CACHE_DIR.mkdir(parents=True, exist_ok=True)
CHART_CACHE_TTL = 3600


def _cache_key(chart_type: str, params: dict) -> str:
    raw = f"{chart_type}:{sorted(params.items())}"
    return hashlib.md5(raw.encode()).hexdigest()


def get_cached_chart(chart_type: str, params: dict) -> Optional[bytes]:
    key = _cache_key(chart_type, params)
    cache_path = CHART_CACHE_DIR / f"{key}.png"
    if cache_path.exists():
        if (time.time() - cache_path.stat().st_mtime) < CHART_CACHE_TTL:
            return cache_path.read_bytes()
    return None


def cache_chart(chart_type: str, params: dict, data: bytes) -> None:
    key = _cache_key(chart_type, params)
    cache_path = CHART_CACHE_DIR / f"{key}.png"
    cache_path.write_bytes(data)


def compress_png(image_bytes: bytes, quality: int = 85) -> bytes:
    img = Image.open(io.BytesIO(image_bytes))
    output = io.BytesIO()
    img.save(output, format="PNG", optimize=True)
    return output.getvalue()


# ═══════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════

def _fig_to_bytes(fig: Figure) -> bytes:
    buf = io.BytesIO()
    fig.savefig(buf, format="png")
    plt.close(fig)
    buf.seek(0)
    return compress_png(buf.getvalue())


def _add_corporate_branding(ax, title: str, xlabel: str = "", ylabel: str = ""):
    ax.set_title(title, color=CORPORATE_BLACK, fontweight="bold", pad=10)
    if xlabel:
        ax.set_xlabel(xlabel, color=CORPORATE_DARK_GRAY)
    if ylabel:
        ax.set_ylabel(ylabel, color=CORPORATE_DARK_GRAY)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#DDDDDD")
    ax.spines["bottom"].set_color("#DDDDDD")
    ax.tick_params(colors=CORPORATE_DARK_GRAY)


# ═══════════════════════════════════════════════════════════════════════
# Graficos
# ═══════════════════════════════════════════════════════════════════════

def chart_planned_vs_realized(
    labels: list,
    planned: list,
    realized: list,
    title: str = "Programado x Realizado",
) -> bytes:
    params = {"labels": labels, "planned": planned, "realized": realized, "title": title}
    cached = get_cached_chart("planned_vs_realized", params)
    if cached:
        return cached

    x = np.arange(len(labels))
    width = 0.35

    fig, ax = plt.subplots(figsize=(7, 3.5))
    bars1 = ax.bar(x - width / 2, planned, width, label="Programado", color=CORPORATE_RED, alpha=0.85)
    bars2 = ax.bar(x + width / 2, realized, width, label="Realizado", color=BLUE, alpha=0.85)

    ax.set_ylabel("Quantidade")
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.legend(frameon=False, fontsize=9)

    for bar in bars1:
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1,
                str(int(bar.get_height())), ha="center", va="bottom", fontsize=7, color=CORPORATE_DARK_GRAY)
    for bar in bars2:
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1,
                str(int(bar.get_height())), ha="center", va="bottom", fontsize=7, color=CORPORATE_DARK_GRAY)

    _add_corporate_branding(ax, title)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("planned_vs_realized", params, data)
    return data


def chart_positive_vs_negative(
    positive: int,
    negative: int,
    title: str = "Positivo x Negativo",
) -> bytes:
    params = {"positive": positive, "negative": negative, "title": title}
    cached = get_cached_chart("positive_vs_negative", params)
    if cached:
        return cached

    total = positive + negative
    pct_positive = (positive / total * 100) if total > 0 else 0
    pct_negative = (negative / total * 100) if total > 0 else 0

    sizes = [positive, negative]
    labels = [f"Seguro\n{positive} ({pct_positive:.1f}%)",
              f"Desvio\n{negative} ({pct_negative:.1f}%)"]
    colors = [GREEN, RED]
    explode = (0.03, 0.03)

    fig, ax = plt.subplots(figsize=(5, 3.5))
    wedges, texts, autotexts = ax.pie(
        sizes, explode=explode, labels=None, colors=colors,
        autopct="", startangle=90, pctdistance=0.6,
        wedgeprops={"edgecolor": "white", "linewidth": 2}
    )

    legend_labels = [f"{l}" for l in labels]
    ax.legend(wedges, legend_labels, loc="lower center", bbox_to_anchor=(0.5, -0.15),
              ncol=2, frameon=False, fontsize=9)

    _add_corporate_branding(ax, title)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("positive_vs_negative", params, data)
    return data


def chart_ofc_by_company(
    companies: list,
    counts: list,
    title: str = "OFS por Empresa",
) -> bytes:
    params = {"companies": companies, "counts": counts, "title": title}
    cached = get_cached_chart("ofc_by_company", params)
    if cached:
        return cached

    items = sorted(zip(companies, counts), key=lambda x: x[1], reverse=True)
    companies = [i[0] for i in items]
    counts = [i[1] for i in items]

    if len(companies) > 8:
        companies = companies[:7] + ["Outros"]
        counts = counts[:7] + [sum(counts[7:])]

    fig, ax = plt.subplots(figsize=(7, 3.5))
    y_pos = np.arange(len(companies))
    colors_list = [COLOR_PALETTE[i % len(COLOR_PALETTE)] for i in range(len(companies))]

    bars = ax.barh(y_pos, counts, height=0.6, color=colors_list, edgecolor="white", linewidth=1)

    for bar, val in zip(bars, counts):
        ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height() / 2,
                str(val), va="center", fontsize=9, color=CORPORATE_DARK_GRAY)

    ax.set_yticks(y_pos)
    ax.set_yticklabels(companies)
    ax.invert_yaxis()
    ax.set_xlabel("Quantidade")

    _add_corporate_branding(ax, title)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("ofc_by_company", params, data)
    return data


def chart_top_behaviors(
    safe: list,
    unsafe: list,
    title: str = "Top Comportamentos",
) -> bytes:
    params = {"safe": safe, "unsafe": unsafe, "title": title}
    cached = get_cached_chart("top_behaviors", params)
    if cached:
        return cached

    fig, (ax_safe, ax_unsafe) = plt.subplots(1, 2, figsize=(8, 4))

    if safe:
        safe_names = [b.get("name", "-")[:40] for b in reversed(safe)]
        safe_counts = [b.get("count", 0) for b in reversed(safe)]
        y_pos = np.arange(len(safe_names))
        ax_safe.barh(y_pos, safe_counts, height=0.6, color="#22C55E", edgecolor="white")
        ax_safe.set_yticks(y_pos)
        ax_safe.set_yticklabels(safe_names, fontsize=7)
        for bar, val in zip(ax_safe.containers[0], safe_counts):
            ax_safe.text(bar.get_width() + 0.3, bar.get_y() + bar.get_height() / 2,
                         str(val), va="center", fontsize=7, color="#666666")
    ax_safe.set_title("Seguros", color="#22C55E", fontweight="bold", fontsize=9)
    ax_safe.spines["top"].set_visible(False)
    ax_safe.spines["right"].set_visible(False)

    if unsafe:
        unsafe_names = [b.get("name", "-")[:40] for b in reversed(unsafe)]
        unsafe_counts = [b.get("count", 0) for b in reversed(unsafe)]
        y_pos = np.arange(len(unsafe_names))
        ax_unsafe.barh(y_pos, unsafe_counts, height=0.6, color="#EF4444", edgecolor="white")
        ax_unsafe.set_yticks(y_pos)
        ax_unsafe.set_yticklabels(unsafe_names, fontsize=7)
        for bar, val in zip(ax_unsafe.containers[0], unsafe_counts):
            ax_unsafe.text(bar.get_width() + 0.3, bar.get_y() + bar.get_height() / 2,
                           str(val), va="center", fontsize=7, color="#666666")
    ax_unsafe.set_title("Inseguros", color="#EF4444", fontweight="bold", fontsize=9)
    ax_unsafe.spines["top"].set_visible(False)
    ax_unsafe.spines["right"].set_visible(False)

    fig.suptitle(title, fontweight="bold", color=CORPORATE_BLACK, fontsize=11, y=1.02)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("top_behaviors", params, data)
    return data


def chart_ofc_by_shift(
    shifts: list,
    counts: list,
    title: str = "OFS por Turno",
) -> bytes:
    params = {"shifts": shifts, "counts": counts, "title": title}
    cached = get_cached_chart("ofc_by_shift", params)
    if cached:
        return cached

    fig, ax = plt.subplots(figsize=(5, 3.5))
    colors_list = COLOR_PALETTE[:len(shifts)]
    wedges, texts, autotexts = ax.pie(
        counts, labels=None, colors=colors_list,
        autopct="%1.0f%%", startangle=90,
        pctdistance=0.75,
        wedgeprops={"edgecolor": "white", "linewidth": 1.5}
    )
    for autotext in autotexts:
        autotext.set_fontsize(8)
        autotext.set_color("white")
        autotext.set_fontweight("bold")

    legend_labels = [f"{s} ({c})" for s, c in zip(shifts, counts)]
    ax.legend(wedges, legend_labels, loc="lower center", bbox_to_anchor=(0.5, -0.12),
              ncol=min(len(shifts), 3), frameon=False, fontsize=9)
    _add_corporate_branding(ax, title)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("ofc_by_shift", params, data)
    return data


def chart_weekly_evolution(
    weeks: list,
    realized: list,
    positive: list,
    negative: list,
    adherence: list = None,
    title: str = "Evolucao Semanal",
) -> bytes:
    params = {
        "weeks": weeks, "realized": realized,
        "positive": positive, "negative": negative,
        "adherence": adherence, "title": title,
    }
    cached = get_cached_chart("weekly_evolution", params)
    if cached:
        return cached

    fig, ax = plt.subplots(figsize=(8, 4))
    x = np.arange(len(weeks))
    ax.plot(x, realized, marker="o", color=CORPORATE_RED, linewidth=2,
            label="Realizadas", markersize=6, zorder=3)
    ax.plot(x, positive, marker="s", color=GREEN, linewidth=2,
            label="Positivas", markersize=5, zorder=3)
    ax.plot(x, negative, marker="^", color=RED, linewidth=2,
            label="Negativas", markersize=5, zorder=3)

    if adherence:
        ax_adh = ax.twinx()
        ax_adh.plot(x, adherence, marker="D", color="#3B82F6", linewidth=2,
                    linestyle="--", label="Aderencia %", markersize=5, zorder=2)
        ax_adh.set_ylabel("Aderencia %", color="#3B82F6")
        ax_adh.tick_params(axis="y", colors="#3B82F6")
        ax_adh.set_ylim(0, max(max(adherence) * 1.2, 120))
        ax_adh.axhline(y=100, color="#22C55E", linestyle=":", linewidth=1, alpha=0.6, label="Meta 100%")
        ax_adh.axhline(y=80, color="#EAB308", linestyle=":", linewidth=1, alpha=0.6, label="Alerta 80%")
        lines1, labels1 = ax.get_legend_handles_labels()
        lines2, labels2 = ax_adh.get_legend_handles_labels()
        ax_adh.legend(lines1 + lines2, labels1 + labels2, frameon=False, fontsize=8, loc="upper left")

    for i, (r, p, n) in enumerate(zip(realized, positive, negative)):
        ax.annotate(str(r), (i, r), textcoords="offset points", xytext=(0, 8),
                    ha="center", fontsize=7, color=CORPORATE_RED, fontweight="bold")

    ax.set_xticks(x)
    ax.set_xticklabels(weeks)
    ax.set_ylabel("Quantidade")
    if not adherence:
        ax.legend(frameon=False, fontsize=9)
    ax.set_ylim(bottom=0)
    _add_corporate_branding(ax, title)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("weekly_evolution", params, data)
    return data


def chart_monthly_comparison(
    weeks: list,
    planned: list,
    realized: list,
    title: str = "Comparativo Semanal do Mes",
) -> bytes:
    params = {"weeks": weeks, "planned": planned, "realized": realized, "title": title}
    cached = get_cached_chart("monthly_comparison", params)
    if cached:
        return cached

    x = np.arange(len(weeks))
    width = 0.3

    fig, ax = plt.subplots(figsize=(7, 3.5))
    ax.bar(x - width / 2, planned, width, label="Programado", color=CORPORATE_GRAY,
           edgecolor=CORPORATE_DARK_GRAY, linewidth=0.5)
    ax.bar(x + width / 2, realized, width, label="Realizado", color=CORPORATE_RED,
           edgecolor="white", linewidth=0.5)

    ax.set_xticks(x)
    ax.set_xticklabels(weeks)
    ax.set_ylabel("Quantidade")
    ax.legend(frameon=False, fontsize=9)
    _add_corporate_branding(ax, title)
    fig.tight_layout()
    data = _fig_to_bytes(fig)
    cache_chart("monthly_comparison", params, data)
    return data


# ═══════════════════════════════════════════════════════════════════════
# ChartSet: container para graficos + conversao base64
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class ChartSet:
    planned_vs_realized: Optional[bytes] = None
    positive_vs_negative: Optional[bytes] = None
    ofc_by_company: Optional[bytes] = None
    ofc_by_shift: Optional[bytes] = None
    weekly_evolution: Optional[bytes] = None
    monthly_comparison: Optional[bytes] = None
    top_behaviors: Optional[bytes] = None

    def to_base64(self) -> dict:
        import base64 as b64
        result = {}
        for field_name in self.__dataclass_fields__:
            value = getattr(self, field_name)
            if value is not None:
                result[field_name] = b64.b64encode(value).decode("utf-8")
        return result


# ═══════════════════════════════════════════════════════════════════════
# Orquestracao de graficos por tipo de relatorio
# ═══════════════════════════════════════════════════════════════════════

def generate_charts_for_weekly(data: dict) -> ChartSet:
    charts = ChartSet()

    charts.planned_vs_realized = chart_planned_vs_realized(
        labels=["OFSS"],
        planned=[data.get("planned", 250)],
        realized=[data.get("realized", 230)],
    )

    charts.positive_vs_negative = chart_positive_vs_negative(
        positive=data.get("positive", 195),
        negative=data.get("negative", 35),
    )

    companies = data.get("companies", [])
    company_counts = data.get("company_counts", [])
    if companies and company_counts:
        charts.ofc_by_company = chart_ofc_by_company(companies, company_counts)

    shifts = data.get("shifts", [])
    shift_counts = data.get("shift_counts", [])
    if shifts and shift_counts:
        charts.ofc_by_shift = chart_ofc_by_shift(shifts, shift_counts)

    weeks = data.get("weeks", [])
    week_realized = data.get("week_realized", [])
    week_positive = data.get("week_positive", [])
    week_negative = data.get("week_negative", [])
    week_adherence = data.get("week_adherence", [])
    if weeks and week_realized:
        charts.weekly_evolution = chart_weekly_evolution(
            weeks, week_realized, week_positive, week_negative,
            adherence=week_adherence if week_adherence else None,
        )

    safe_behaviors = data.get("top_safe", [])
    unsafe_behaviors = data.get("top_unsafe", [])
    if safe_behaviors or unsafe_behaviors:
        charts.top_behaviors = chart_top_behaviors(safe_behaviors, unsafe_behaviors)

    return charts


def generate_charts_for_monthly(data: dict) -> ChartSet:
    charts = ChartSet()
    weeks = data.get("weeks", [])
    week_planned = data.get("week_planned", [])
    week_realized = data.get("week_realized", [])
    if weeks and week_planned and week_realized:
        charts.monthly_comparison = chart_monthly_comparison(weeks, week_planned, week_realized)
    charts.positive_vs_negative = chart_positive_vs_negative(
        positive=data.get("monthly_positive", 820),
        negative=data.get("monthly_negative", 160),
    )
    charts.weekly_evolution = chart_weekly_evolution(
        weeks=weeks,
        realized=week_realized,
        positive=data.get("week_positive", []),
        negative=data.get("week_negative", []),
    )
    return charts


def generate_charts_for_company(data: dict) -> ChartSet:
    charts = ChartSet()
    charts.planned_vs_realized = chart_planned_vs_realized(
        labels=["OFSS"],
        planned=[data.get("planned", 120)],
        realized=[data.get("realized", 115)],
    )
    shifts = data.get("shifts", [])
    shift_counts = data.get("shift_counts", [])
    if shifts and shift_counts:
        charts.ofc_by_shift = chart_ofc_by_shift(shifts, shift_counts)
    return charts
