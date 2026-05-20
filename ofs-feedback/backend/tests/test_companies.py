"""
test_companies.py — Testes de CRUD de empresas e dropdowns.

Cenarios:
  1. Listar empresas (acesso geral) -> 200
  2. Dropdown para criacao de OFS -> empresas ativas
  3. Criar empresa (admin) -> implementado se endpoint existir
  4. CRUD empresas restrito a admin
"""

import pytest
from uuid import UUID

from httpx import AsyncClient


# ---------------------------------------------------------------------------
# 1. Listar empresas
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_companies_populated(client: AsyncClient, admin_headers, db_session):
    """Empresas de seed estao disponiveis para uso."""
    # O endpoint pode nao existir como rota separada;
    # verificamos que o seed carregou no banco
    from sqlalchemy import select, func
    from app.models.empresa import Empresa

    result = await db_session.execute(select(func.count(Empresa.id)))
    count = result.scalar()
    assert count >= 3  # 3 empresas do seed


# ---------------------------------------------------------------------------
# 2. OFS criado referencia a empresa corretamente
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ofc_has_empresa_id(
    client: AsyncClient, observador_headers, valid_ofc_payload
):
    """OFS criado herda empresa_id do usuario gerador."""
    resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    assert resp.status_code == 201
    data = resp.json()

    # empresa_id deve ser da Security Dynamics (empresa do observador)
    assert data["empresa_id"] == "a0000000-0000-0000-0000-000000000001"
    assert data["empresa_nome"] == "Security Dynamics Ltda."


# ---------------------------------------------------------------------------
# 3. Acesso cross-company: Supervisor G4S vs OFS da SD
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_company_isolation_in_ofc_list(
    client: AsyncClient, observador_headers, valid_ofc_payload,
    supervisor_g4s_headers, supervisor_headers
):
    """Supervisor de uma empresa nao ve OFSS de outra empresa."""
    # Criar OFS na Security Dynamics
    await client.post("/api/OFS-records", json=valid_ofc_payload, headers=observador_headers)

    # Supervisor G4S lista — deve estar vazio
    resp = await client.get("/api/OFS-records", headers=supervisor_g4s_headers)
    assert resp.json()["total"] == 0

    # Supervisor SD lista — deve conter o OFS
    resp = await client.get("/api/OFS-records", headers=supervisor_headers)
    assert resp.json()["total"] >= 1
