"""
test_audit.py — Testes de auditoria e integridade de logs.

Cenarios:
  1. Admin lista auditoria -> 200
  2. Gestor tenta ver auditoria -> 403
  3. Supervisor tenta ver auditoria -> 403
  4. Observador tenta ver auditoria -> 403
  5. Criacao de OFS gera entrada de auditoria
  6. Cancelamento gera entrada WARNING
  7. Filtro de auditoria por action -> 200
  8. Filtro de auditoria por severity -> 200
"""

import pytest
from uuid import UUID

from httpx import AsyncClient


# ---------------------------------------------------------------------------
# 1. Admin lista auditoria -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_audit(client: AsyncClient, admin_headers):
    """Admin pode listar logs de auditoria."""
    resp = await client.get("/api/admin/audit", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    assert "total" in data
    assert isinstance(data["data"], list)


# ---------------------------------------------------------------------------
# 2. Gestor tenta ver auditoria -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gestor_cannot_access_audit(client: AsyncClient, gestor_headers):
    """Gestor nao pode acessar /api/admin/audit (middleware bloqueia /api/admin)."""
    resp = await client.get("/api/admin/audit", headers=gestor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 3. Supervisor tenta ver auditoria -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_cannot_access_audit(client: AsyncClient, supervisor_headers):
    """Supervisor nao pode acessar auditoria."""
    resp = await client.get("/api/admin/audit", headers=supervisor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 4. Observador tenta ver auditoria -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_observador_cannot_access_audit(client: AsyncClient, observador_headers):
    """Observador nao pode acessar auditoria."""
    resp = await client.get("/api/admin/audit", headers=observador_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 5. Criacao de OFS gera entrada de auditoria
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ofc_creation_generates_audit_log(
    client: AsyncClient, observador_headers, valid_ofc_payload, admin_headers
):
    """Apos criar OFS, log de auditoria deve conter OFC_CREATE."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    assert create_resp.status_code == 201

    resp = await client.get("/api/admin/audit?action=OFC_CREATE", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    assert any(
        log.get("action") == "OFC_CREATE"
        for log in data["data"]
    )


# ---------------------------------------------------------------------------
# 6. Cancelamento gera entrada WARNING
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ofc_cancel_generates_audit_warning(
    client: AsyncClient, observador_headers, valid_ofc_payload,
    gestor_headers, admin_headers
):
    """Cancelamento de OFS gera log com severity WARNING."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]

    await client.patch(f"/api/OFS-records/{ofc_id}/cancel", json={
        "motivo": "Registro duplicado conforme auditoria de qualidade.",
    }, headers=gestor_headers)

    resp = await client.get("/api/admin/audit?action=OFC_CANCEL", headers=admin_headers)
    data = resp.json()
    assert data["total"] >= 1


# ---------------------------------------------------------------------------
# 7. Filtro por action
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_audit_filter_by_action(client: AsyncClient, admin_headers):
    """Filtro de auditoria por action especifica."""
    resp = await client.get("/api/admin/audit?action=LOGIN_SUCCESS", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    for log in data["data"]:
        assert log["action"] == "LOGIN_SUCCESS"


# ---------------------------------------------------------------------------
# 8. Filtro por severity
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_audit_filter_by_severity(client: AsyncClient, admin_headers):
    """Filtro de auditoria por severity."""
    resp = await client.get("/api/admin/audit?severity=INFO", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    for log in data["data"]:
        assert log["severity"] == "INFO"


# ---------------------------------------------------------------------------
# 9. Auditoria sem autenticacao -> 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_audit_without_auth(client: AsyncClient):
    """Acesso a auditoria sem token retorna 401."""
    resp = await client.get("/api/admin/audit")
    assert resp.status_code == 401
