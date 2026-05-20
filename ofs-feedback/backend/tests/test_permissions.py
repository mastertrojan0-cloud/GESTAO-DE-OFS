"""
test_permissions.py — Testes de RBAC (Role-Based Access Control).

Matriz testada:
  ┌──────────────────────┬────────────┬────────────┬────────┬───────┐
  │ Acao                 │ Observador │ Supervisor │ Gestor │ Admin │
  ├──────────────────────┼────────────┼────────────┼────────┼───────┤
  │ Criar OFS            │    200     │    200     │  200   │  200  │
  │ Ver OFSS proprios    │    200     │    200     │  200   │  200  │
  │ Ver OFS outro usu.   │    403     │    N/A     │  200   │  200  │
  │ Ver OFS outra empr.  │    N/A     │    403     │  200   │  200  │
  │ Editar OFS proprio   │  200/409   │  200/409   │  200   │  200  │
  │ Editar OFS outro     │    403     │    403     │  200   │  200  │
  │ Cancelar OFS         │    403     │    403     │  200   │  200  │
  │ Restaurar OFS        │    403     │    403     │  403   │  200  │
  │ Ver Metricas         │    200*    │    200     │  200   │  200  │
  │ Ver Auditoria        │    403     │    403     │  403   │  200  │
  │ Invalidar Cache      │    403     │    403     │  200   │  200  │
  └──────────────────────┴────────────┴────────────┴────────┴───────┘
  *Observador ve metricas com data scoping (ALL_ROLES no endpoint atual).

Cenarios:
  1. Observador tenta ver OFS de outro -> 403
  2. Supervisor tenta ver OFS de outra empresa -> 403
  3. Observador tenta cancelar -> 403 (middleware)
  4. Supervisor tenta cancelar -> 403 (middleware)
  5. Gestor tenta ver auditoria -> 403 (middleware)
  6. Supervisor tenta acessar admin -> 403 (middleware)
  7. Observador tenta acessar admin -> 403 (middleware)
  8. Gestor tenta restaurar OFS -> 403
  9. Admin acesso total a tudo
 10. Supervisor ve apenas OFSS da sua empresa
 11. Observador edita apenas seus OFSS dentro de 24h
 12. Gestor/Admin editam qualquer OFS sem limite
"""

import pytest
from datetime import date, timedelta
from uuid import UUID, uuid4

from httpx import AsyncClient


# ---------------------------------------------------------------------------
# 1. Observador tenta ver OFS de outro -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_observador_cannot_see_other_ofc(
    client: AsyncClient, observador_headers, gestor_headers, valid_ofc_payload
):
    """Observador nao pode acessar OFS criado por gestor."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=gestor_headers
    )
    ofc_id = create_resp.json()["id"]

    resp = await client.get(f"/api/OFS-records/{ofc_id}", headers=observador_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 2. Supervisor tenta ver OFS de outra empresa -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_cannot_see_other_company_ofc(
    client: AsyncClient, observador_headers, valid_ofc_payload,
    supervisor_headers, supervisor_g4s_headers
):
    """Supervisor da G4S nao pode ver OFS da Security Dynamics."""
    # Criar OFS na Security Dynamics
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]

    # Supervisor da G4S tenta acessar
    resp = await client.get(f"/api/OFS-records/{ofc_id}", headers=supervisor_g4s_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 3. Observador tenta cancelar -> 403 (middleware)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_observador_cannot_cancel(
    client: AsyncClient, observador_headers, valid_ofc_payload
):
    """Observador nao pode cancelar OFSS (middleware PATCH /api/OFS-records)."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/OFS-records/{ofc_id}/cancel", json={
        "motivo": "Tentativa de cancelamento nao autorizada.",
    }, headers=observador_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 4. Supervisor tenta cancelar -> 403 (middleware)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_cannot_cancel(
    client: AsyncClient, observador_headers, valid_ofc_payload, supervisor_headers
):
    """Supervisor nao pode cancelar OFSS."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/OFS-records/{ofc_id}/cancel", json={
        "motivo": "Tentativa de cancelamento como supervisor.",
    }, headers=supervisor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 5. Gestor tenta ver auditoria -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gestor_cannot_access_audit(client: AsyncClient, gestor_headers):
    """Gestor nao pode acessar endpoints de auditoria (/api/admin/*)."""
    resp = await client.get("/api/admin/audit", headers=gestor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 6. Supervisor tenta acessar /api/admin -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_cannot_access_admin(client: AsyncClient, supervisor_headers):
    """Supervisor nao pode acessar nenhum endpoint /api/admin."""
    resp = await client.get("/api/admin/audit", headers=supervisor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 7. Observador tenta acessar /api/admin -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_observador_cannot_access_admin(client: AsyncClient, observador_headers):
    """Observador nao pode acessar /api/admin."""
    resp = await client.get("/api/admin/audit", headers=observador_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 8. Gestor tenta restaurar OFS -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gestor_cannot_restore(
    client: AsyncClient, observador_headers, valid_ofc_payload,
    gestor_headers
):
    """Gestor nao pode restaurar OFS (apenas Admin)."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]

    # Cancelar como gestor
    await client.patch(f"/api/OFS-records/{ofc_id}/cancel", json={
        "motivo": "Motivo para cancelamento em teste de perm.",

    }, headers=gestor_headers)

    # Tentar restaurar como gestor
    resp = await client.post(f"/api/OFS-records/{ofc_id}/restore", headers=gestor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 9. Admin acesso total -> todos endpoints funcionam
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_full_access(
    client: AsyncClient, admin_headers, valid_ofc_payload,
    observador_headers, gestor_headers
):
    """Admin pode criar, ver, editar, cancelar e restaurar OFSS."""
    # Criar
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=admin_headers
    )
    assert create_resp.status_code == 201
    ofc_id = create_resp.json()["id"]
    updated_at = create_resp.json()["updated_at"]

    # Ver
    resp = await client.get(f"/api/OFS-records/{ofc_id}", headers=admin_headers)
    assert resp.status_code == 200

    # Ver auditoria
    resp = await client.get("/api/admin/audit", headers=admin_headers)
    assert resp.status_code == 200

    # Editar
    resp = await client.put(f"/api/OFS-records/{ofc_id}", json={
        "comportamento": "Admin editou: comportamento seguro exemplar.",
        "updated_at": updated_at,
    }, headers=admin_headers)
    assert resp.status_code == 200

    # Cancelar
    resp = await client.patch(f"/api/OFS-records/{ofc_id}/cancel", json={
        "motivo": "Cancelamento pelo admin para teste.",
    }, headers=admin_headers)
    assert resp.status_code == 200

    # Restaurar
    resp = await client.post(f"/api/OFS-records/{ofc_id}/restore", headers=admin_headers)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# 10. Supervisor ve apenas OFSS da sua empresa
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_list_scoped_by_company(
    client: AsyncClient, observador_headers, valid_ofc_payload,
    supervisor_headers, supervisor_g4s_headers
):
    """Supervisor de empresa A nao ve OFSS da empresa B na listagem."""
    # Criar OFS na Security Dynamics
    await client.post("/api/OFS-records", json=valid_ofc_payload, headers=observador_headers)

    # Supervisor G4S nao deve ver
    resp = await client.get("/api/OFS-records", headers=supervisor_g4s_headers)
    data = resp.json()
    assert data["total"] == 0

    # Supervisor SD deve ver
    resp = await client.get("/api/OFS-records", headers=supervisor_headers)
    data = resp.json()
    assert data["total"] >= 1


# ---------------------------------------------------------------------------
# 11. Observador edita apenas seus OFSS dentro de 24h
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_observador_cannot_edit_others_ofc(
    client: AsyncClient, observador_headers, gestor_headers, valid_ofc_payload
):
    """Observador nao pode editar OFS criado por outro usuario."""
    # Gestor cria OFS
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=gestor_headers
    )
    ofc_id = create_resp.json()["id"]
    updated_at = create_resp.json()["updated_at"]

    # Observador tenta editar
    resp = await client.put(f"/api/OFS-records/{ofc_id}", json={
        "comportamento": "Observador tentando editar OFS de gestor.",
        "updated_at": updated_at,
    }, headers=observador_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 12. Gestor/Admin editam qualquer OFS sem limite
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_gestor_edits_any_ofc(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers
):
    """Gestor pode editar OFS criado por observador."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]
    updated_at = create_resp.json()["updated_at"]

    resp = await client.put(f"/api/OFS-records/{ofc_id}", json={
        "comportamento": "Gestor editou: comportamento revisado.",
        "updated_at": updated_at,
    }, headers=gestor_headers)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# 13. Cross-company: Supervisor nao edita OFS de outra empresa
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_cannot_edit_other_company_ofc(
    client: AsyncClient, observador_headers, valid_ofc_payload,
    supervisor_g4s_headers
):
    """Supervisor da G4S nao pode editar OFS da Security Dynamics."""
    create_resp = await client.post(
        "/api/OFS-records", json=valid_ofc_payload, headers=observador_headers
    )
    ofc_id = create_resp.json()["id"]
    updated_at = create_resp.json()["updated_at"]

    resp = await client.put(f"/api/OFS-records/{ofc_id}", json={
        "comportamento": "Supervisor G4S tentando editar OFS de SD.",
        "updated_at": updated_at,
    }, headers=supervisor_g4s_headers)
    assert resp.status_code == 403
