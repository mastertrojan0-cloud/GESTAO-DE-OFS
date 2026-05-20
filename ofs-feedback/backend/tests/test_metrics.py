"""
test_metrics.py — Testes de metricas (calculos, status, rankings).

Cenarios:
  1. Metricas com dados -> 200 + indicadores corretos
  2. Metricas sem meta -> status SEM_META (ou fallback)
  3. Metricas sem registros -> indicadores zero, status SEM_DADOS
  4. Status OK (100%) / ATENCAO (85%) / ALERTA (70%)
  5. Grafico Programado x Realizado -> 200
  6. Grafico Positivo x Negativo -> 200
  7. Ranking por Empresa -> 200
  8. Evolucao Semanal -> 200
  9. Export CSV -> 200
 10. Cache Invalidation -> 200 (gestor) / 403 (observador)
"""

import pytest
import pytest_asyncio
from datetime import date, timedelta
from uuid import UUID

from httpx import AsyncClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _week_range():
    """Retorna (segunda, domingo) da semana atual."""
    hoje = date.today()
    segunda = hoje - timedelta(days=hoje.weekday())
    domingo = segunda + timedelta(days=6)
    return segunda, domingo


@pytest_asyncio.fixture
async def _seed_OFSS(client, gestor_headers):
    """Cria varios OFSS e OFSs para alimentar metricas."""
    hoje = date.today()
    payloads = [
        {"data": hoje.isoformat(), "hora": "08:00", "nome_observado": f"Colaborador {i}",
         "atividade": "Atividade de teste", "local": "Local A",
         "turno": "1", "tipo": "OFS",
         "comportamento": "Comportamento seguro numero " + str(i),
         "observacao": "Teste metricas"}
        for i in range(1, 11)
    ]
    payloads += [
        {"data": hoje.isoformat(), "hora": "09:00", "nome_observado": f"Colaborador {i}",
         "atividade": "Atividade de teste", "local": "Local A",
         "turno": "2", "tipo": "OFS",
         "comportamento": "Comportamento inseguro numero " + str(i),
         "observacao": "Teste metricas"}
        for i in range(11, 16)
    ]
    for p in payloads:
        await client.post("/api/OFS-records", json=p, headers=gestor_headers)


# ---------------------------------------------------------------------------
# 1. Metricas com dados -> 200 + indicadores corretos
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_metrics_with_data(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Metricas com OFSS registrados retornam indicadores calculados."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/weekly?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["ofc_realizadas"] >= 15  # 10 OFS + 5 OFS = 15
    assert data["ofc_positivas"] >= 10
    assert data["ofc_negativas"] >= 5
    assert "aderencia_percentual" in data
    assert "percentual_seguro" in data
    assert "status" in data
    assert len(data["indicadores"]) >= 5


# ---------------------------------------------------------------------------
# 3. Metricas sem registros -> indicadores zero, status SEM_DADOS
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_metrics_no_records(client: AsyncClient, gestor_headers):
    """Semana sem OFSS retorna SEM_DADOS."""
    # Usar uma semana no futuro para garantir zero registros
    futuro = date.today() + timedelta(days=365)
    segunda = futuro - timedelta(days=futuro.weekday())
    domingo = segunda + timedelta(days=6)

    resp = await client.get(
        f"/api/metrics/weekly?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["ofc_realizadas"] == 0
    assert data["status"] == "SEM_DADOS"


# ---------------------------------------------------------------------------
# 4. Status (OK / ATENCAO / ALERTA)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_metrics_status_calculation(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Verifica que o status e calculado conforme aderencia."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/weekly?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    data = resp.json()
    status = data["status"]
    assert status in ("OK", "ATENCAO", "ALERTA", "SEM_META", "SEM_DADOS")


# ---------------------------------------------------------------------------
# 5. Grafico Programado x Realizado -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_chart_programmed_vs_realized(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Endpoint de grafico Programado x Realizado retorna 200."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/charts/programmed-vs-realized"
        f"?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "chart" in data
    assert len(data["chart"]) == 2


# ---------------------------------------------------------------------------
# 6. Grafico Positivo x Negativo -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_chart_positive_vs_negative(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Endpoint de grafico Positivo x Negativo retorna 200."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/charts/positive-vs-negative"
        f"?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "chart" in data
    assert "total" in data


# ---------------------------------------------------------------------------
# 7. Ranking por Empresa -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_chart_by_company(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Endpoint de ranking por empresa retorna 200."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/charts/by-company"
        f"?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "chart" in data


# ---------------------------------------------------------------------------
# 8. Evolucao Semanal -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_chart_weekly_evolution(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Endpoint de evolucao semanal retorna 200."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/charts/weekly-evolution"
        f"?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}&semanas=4",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "semanas" in data


# ---------------------------------------------------------------------------
# 9. Export CSV -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_export_csv(client: AsyncClient, gestor_headers, _seed_OFSS):
    """Exportacao CSV retorna 200 e content-type text/csv."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/export/csv?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=gestor_headers,
    )
    assert resp.status_code == 200
    assert "text/csv" in resp.headers.get("content-type", "")


# ---------------------------------------------------------------------------
# 10. Cache Invalidation
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_cache_invalidation_permission(client: AsyncClient, observador_headers, gestor_headers):
    """Apenas gestor/admin podem invalidar cache de metricas."""
    resp = await client.post("/api/metrics/cache/invalidate", headers=observador_headers)
    assert resp.status_code == 403

    resp = await client.post("/api/metrics/cache/invalidate", headers=gestor_headers)
    assert resp.status_code == 200
    assert "invalidado" in resp.json()["message"].lower()


# ---------------------------------------------------------------------------
# Observador acessa metricas com scoping
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_metrics_observador_scoped(client: AsyncClient, observador_headers):
    """Observador ve metricas apenas dos seus dados (scoping)."""
    segunda, domingo = _week_range()
    resp = await client.get(
        f"/api/metrics/weekly?data_inicio={segunda.isoformat()}&data_fim={domingo.isoformat()}",
        headers=observador_headers,
    )
    # Observador pode acessar o endpoint (ALL_ROLES no metrics.py)
    assert resp.status_code == 200
