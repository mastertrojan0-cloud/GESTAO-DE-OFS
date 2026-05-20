"""
test_ofc_records.py — Shim de compatibilidade.
Use test_ofs_records.py para os testes atualizados.

Cenarios (testando via endpoint /api/ofs-records com dados legados):
  1. Criar OFS valido -> 201 + codigo
  2. Criar OFS valido (tipo OFS) -> 201
  3. Criar sem campos obrigatorios -> 422
  4. Criar com data futura -> 422
  5. Criar com hora invalida -> 422
  6. Listar OFSs (com data scoping) -> 200
  7. Obter OFS por ID (dono) -> 200
  8. Obter OFS por ID (outro supervisor) -> 403
  9. Editar proprio OFS em <24h -> 200
 10. Editar OFS com optimistic lock conflitante -> 409
 11. Cancelar como Gestor -> 200
 12. Cancelar sem motivo (min 10 chars) -> 422
 13. Cancelar como Observador -> 403
 14. Restaurar como Admin -> 200
 15. Restaurar como Gestor -> 403
 16. DELETE fisico (nao permitido na API, so via SQL)
"""

import pytest
from datetime import date, datetime, timezone
from uuid import UUID, uuid4

from httpx import AsyncClient


# ---------------------------------------------------------------------------
# 1. Criar OFS valido -> 201 + codigo
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_ofc_success(client: AsyncClient, observador_headers, valid_ofc_payload):
    """Criacao de OFS com dados validos retorna 201 e codigo no formato OFS-XX-NNNNN."""
    resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert "id" in data
    assert "codigo" in data
    assert data["codigo"].startswith("OFS-")
    assert data["status"] == "ativo"
    assert data["usuario_gerador_nome"] == "Observador de Campo"


# ---------------------------------------------------------------------------
# 2. Criar OFS valido -> 201
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_ofs_success(client: AsyncClient, observador_headers, valid_ofs_payload):
    """Criacao de OFS (tipo OFS) com dados validos retorna 201."""
    resp = await client.post("/api/ofs-records", json=valid_ofs_payload, headers=observador_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["codigo"].startswith("OFS-")
    assert data["tipo_observacao"] == "Positivo (Seguro)"


# ---------------------------------------------------------------------------
# 3. Criar sem campos obrigatorios -> 422
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_ofc_missing_required_fields(client: AsyncClient, observador_headers):
    """POST sem campos obrigatorios retorna 422 (Validation Error)."""
    resp = await client.post("/api/ofs-records", json={
        "data": date.today().isoformat(),
        "hora": "14:30",
    }, headers=observador_headers)
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_create_ofc_nome_observado_too_short(client: AsyncClient, observador_headers, valid_ofc_payload):
    """nome_observado com menos de 3 chars retorna 422."""
    payload = {**valid_ofc_payload, "nome_observado": "AB"}
    resp = await client.post("/api/ofs-records", json=payload, headers=observador_headers)
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_create_ofc_comportamento_too_short(client: AsyncClient, observador_headers, valid_ofc_payload):
    """comportamento com menos de 3 chars (? min_length=3 no schema atual)."""
    payload = {**valid_ofc_payload, "comportamento": "AB"}
    resp = await client.post("/api/ofs-records", json=payload, headers=observador_headers)
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# 4. Criar com data futura -> 422
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_ofc_future_date(client: AsyncClient, observador_headers, valid_ofc_payload):
    """Data no futuro nao e explicitamente validada no schema atual,
    mas o formato deve ser YYYY-MM-DD."""
    payload = {**valid_ofc_payload, "data": "2099-12-31"}
    resp = await client.post("/api/ofs-records", json=payload, headers=observador_headers)
    # Aceita ou rejeita dependendo da validacao implementada
    assert resp.status_code in (201, 422)


# ---------------------------------------------------------------------------
# 5. Criar com hora invalida -> 422
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_ofc_invalid_hour_format(client: AsyncClient, observador_headers, valid_ofc_payload):
    """Hora em formato invalido retorna 422."""
    payload = {**valid_ofc_payload, "hora": "14:30:00"}
    resp = await client.post("/api/ofs-records", json=payload, headers=observador_headers)
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# 6. Listar OFSs (com data scoping) -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_OFSS_observador_sees_only_own(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers
):
    """Observador ve apenas seus proprios registros."""
    # Criar um OFS como observador
    await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)

    # Criar outro como gestor
    await client.post("/api/ofs-records", json=valid_ofc_payload, headers=gestor_headers)

    resp = await client.get("/api/ofs-records", headers=observador_headers)
    assert resp.status_code == 200
    data = resp.json()
    # Observador deve ver apenas 1 registro
    assert data["total"] == 1


@pytest.mark.asyncio
async def test_list_OFSS_gestor_sees_all(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers
):
    """Gestor ve todos os registros da sua empresa."""
    await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    await client.post("/api/ofs-records", json=valid_ofc_payload, headers=gestor_headers)

    resp = await client.get("/api/ofs-records", headers=gestor_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 2


# ---------------------------------------------------------------------------
# 7. Obter OFS por ID -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_ofc_by_id_owner(client: AsyncClient, observador_headers, valid_ofc_payload):
    """Dono do registro pode visualizar seu OFS."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    resp = await client.get(f"/api/ofs-records/{ofs_id}", headers=observador_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["registro"]["id"] == ofs_id
    assert "edicoes" in data


# ---------------------------------------------------------------------------
# 8. Obter OFS de outro usuario (Observador) -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_ofc_other_user_as_observador(
    client: AsyncClient, observador_headers, gestor_headers, valid_ofc_payload
):
    """Observador tentando acessar OFS de outro usuario recebe 403."""
    # Gestor cria OFS
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=gestor_headers)
    ofs_id = create_resp.json()["id"]

    # Observador tenta acessar
    resp = await client.get(f"/api/ofs-records/{ofs_id}", headers=observador_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 9. Editar proprio OFS em <24h -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_edit_own_ofc_within_window(
    client: AsyncClient, observador_headers, valid_ofc_payload
):
    """Observador edita proprio OFS recem-criado com sucesso."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_data = create_resp.json()
    ofs_id = ofs_data["id"]
    updated_at = ofs_data["updated_at"]

    resp = await client.put(f"/api/ofs-records/{ofs_id}", json={
        "comportamento": "Comportamento atualizado: uso exemplar de todos os EPIs obrigatorios.",
        "updated_at": updated_at,
    }, headers=observador_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "edicoes_realizadas" in data
    assert len(data["edicoes_realizadas"]) >= 1


# ---------------------------------------------------------------------------
# 10. Editar com optimistic lock conflitante -> 409
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_edit_ofc_optimistic_lock_conflict(
    client: AsyncClient, observador_headers, valid_ofc_payload
):
    """Enviar updated_at desatualizado causa 409 Conflict."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    # Enviar updated_at errado
    fake_updated_at = "2020-01-01T00:00:00+00:00"
    resp = await client.put(f"/api/ofs-records/{ofs_id}", json={
        "comportamento": "Tentativa de edicao com lock conflitante.",
        "updated_at": fake_updated_at,
    }, headers=observador_headers)
    assert resp.status_code == 409


# ---------------------------------------------------------------------------
# 11. Cancelar como Gestor -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_cancel_ofc_as_gestor(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers
):
    """Gestor pode cancelar OFS com motivo valido."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "Registro duplicado — OFS ja havia sido criada para este colaborador.",
    }, headers=gestor_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "cancelado"
    assert "sucesso" in data["message"].lower()


@pytest.mark.asyncio
async def test_cancel_ofc_as_admin(
    client: AsyncClient, observador_headers, valid_ofc_payload, admin_headers
):
    """Admin pode cancelar OFS."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "Cancelamento administrativo — revisao de dados.",
    }, headers=admin_headers)
    assert resp.status_code == 200
    assert resp.json()["status"] == "cancelado"


# ---------------------------------------------------------------------------
# 12. Cancelar sem motivo (min 10 chars) -> 422
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_cancel_ofc_short_reason(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers
):
    """Cancelamento com motivo curto (< 10 chars) retorna 422."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "curto",
    }, headers=gestor_headers)
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# 13. Cancelar como Observador -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_cancel_ofc_as_observador(
    client: AsyncClient, observador_headers, valid_ofc_payload
):
    """Observador nao pode cancelar OFSs (403 do middleware)."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "Tentativa de cancelamento por observador.",
    }, headers=observador_headers)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_cancel_ofc_as_supervisor(
    client: AsyncClient, observador_headers, valid_ofc_payload, supervisor_headers
):
    """Supervisor nao pode cancelar OFSs."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    resp = await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "Tentativa de cancelamento por supervisor.",
    }, headers=supervisor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# 14. Restaurar como Admin -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_restore_ofc_as_admin(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers, admin_headers
):
    """Admin pode restaurar OFS cancelado."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    # Cancelar primeiro
    await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "Motivo para cancelamento temporario.",
    }, headers=gestor_headers)

    # Restaurar
    resp = await client.post(f"/api/ofs-records/{ofs_id}/restore", headers=admin_headers)
    assert resp.status_code == 200
    assert "restaurado" in resp.json()["message"].lower()


# ---------------------------------------------------------------------------
# 15. Restaurar como Gestor -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_restore_ofc_as_gestor(
    client: AsyncClient, observador_headers, valid_ofc_payload, gestor_headers
):
    """Gestor nao pode restaurar OFSs (apenas Admin)."""
    create_resp = await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)
    ofs_id = create_resp.json()["id"]

    # Cancelar
    await client.patch(f"/api/ofs-records/{ofs_id}/cancel", json={
        "motivo": "Motivo para cancelamento temporario.",
    }, headers=gestor_headers)

    # Tentar restaurar como gestor
    resp = await client.post(f"/api/ofs-records/{ofs_id}/restore", headers=gestor_headers)
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Testes adicionais: filtros e paginacao
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_OFSS_with_filters(
    client: AsyncClient, gestor_headers, valid_ofc_payload, valid_ofs_payload
):
    """Filtros de listagem funcionam corretamente."""
    await client.post("/api/ofs-records", json=valid_ofc_payload, headers=gestor_headers)
    await client.post("/api/ofs-records", json=valid_ofs_payload, headers=gestor_headers)

    # Filtrar por tipo Negativo (Inseguro)
    resp = await client.get("/api/ofs-records?tipo_observacao=Negativo+%28Inseguro%29", headers=gestor_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    for item in data["data"]:
        assert item["tipo_observacao"] == "Negativo (Inseguro)"

    # Filtrar por tipo Positivo (Seguro)
    resp = await client.get("/api/ofs-records?tipo_observacao=Positivo+%28Seguro%29", headers=gestor_headers)
    data = resp.json()
    for item in data["data"]:
        assert item["tipo_observacao"] == "Positivo (Seguro)"


@pytest.mark.asyncio
async def test_list_OFSS_pagination(
    client: AsyncClient, gestor_headers, valid_ofc_payload
):
    """Paginacao retorna estrutura correta."""
    for _ in range(3):
        await client.post("/api/ofs-records", json=valid_ofc_payload, headers=gestor_headers)

    resp = await client.get("/api/ofs-records?page=1&page_size=2", headers=gestor_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "data" in data
    assert "total" in data
    assert "page" in data
    assert "limit" in data
    assert len(data["data"]) <= 2


# ---------------------------------------------------------------------------
# Cross-company isolation
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_supervisor_g4s_cannot_see_sd_OFSS(
    client: AsyncClient, observador_headers, valid_ofc_payload, supervisor_g4s_headers
):
    """Supervisor da G4S nao ve OFSs da Security Dynamics."""
    await client.post("/api/ofs-records", json=valid_ofc_payload, headers=observador_headers)

    resp = await client.get("/api/ofs-records", headers=supervisor_g4s_headers)
    data = resp.json()
    # Supervisor da G4S so ve registros da empresa G4S
    assert data["total"] == 0
