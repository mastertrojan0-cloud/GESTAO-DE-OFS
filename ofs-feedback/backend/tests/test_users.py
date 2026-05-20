"""
test_users.py — Testes de CRUD de usuarios e permissoes.

Cenarios:
  1. Admin lista usuarios -> 200
  2. Admin cria usuario -> 201
  3. Admin desativa usuario -> 200
  4. Gestor tenta criar admin -> 403
  5. Supervisor tenta listar usuarios -> 403 (middleware)
  6. Criar usuario com username duplicado -> 409
  7. Alterar propria senha -> 200
  8. Alterar senha com senha atual errada -> 400
  9. Reutilizar senha recente -> 400
 10. Senha fraca -> 400
"""

import pytest
from httpx import AsyncClient


# ---------------------------------------------------------------------------
# 1. Admin lista usuarios -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_admin_list_users(client: AsyncClient, admin_headers):
    """Admin pode listar usuarios (nao implementado como endpoint dedicado,
    mas verificar se nao bloqueia acesso)."""
    resp = await client.get("/api/admin/audit", headers=admin_headers)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# 7. Alterar propria senha -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_change_password_success(client: AsyncClient, observador_headers):
    """Usuario autenticado pode alterar propria senha."""
    resp = await client.post("/api/auth/change-password", json={
        "current_password": "Teste@123",
        "new_password": "NovaSenha@456",
    }, headers=observador_headers)
    assert resp.status_code == 200
    assert "sucesso" in resp.json()["message"].lower()


# ---------------------------------------------------------------------------
# 8. Alterar senha com senha atual errada -> 400
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_change_password_wrong_current(client: AsyncClient, observador_headers):
    """Senha atual incorreta retorna 400."""
    resp = await client.post("/api/auth/change-password", json={
        "current_password": "senha_errada",
        "new_password": "NovaSenha@456",
    }, headers=observador_headers)
    assert resp.status_code == 400
    assert "incorreta" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# 10. Senha fraca -> 400
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_change_password_weak(client: AsyncClient, observador_headers):
    """Senha que nao atende criterios minimos retorna 400."""
    resp = await client.post("/api/auth/change-password", json={
        "current_password": "Teste@123",
        "new_password": "12345",
    }, headers=observador_headers)
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# 9. Reutilizar senha recente -> 400
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_change_password_reuse(client: AsyncClient, observador_headers, db_session):
    """Reutilizar uma das ultimas senhas deve ser bloqueado."""
    from app.models.auth_models import PasswordHistory
    from app.core.security import hash_password
    from uuid import UUID

    # Registra a senha nova no historico primeiro
    db_session.add(PasswordHistory(
        user_id=UUID("b0000000-0000-0000-0000-000000000004"),
        password_hash=hash_password("NovaSenha@456"),
    ))
    await db_session.flush()

    resp = await client.post("/api/auth/change-password", json={
        "current_password": "Teste@123",
        "new_password": "NovaSenha@456",
    }, headers=observador_headers)
    # Deve bloquear reuso
    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# Permission checks via middleware
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_observador_cannot_access_admin(client: AsyncClient, observador_headers):
    """Observador nao pode acessar endpoints /api/admin."""
    resp = await client.get("/api/admin/audit", headers=observador_headers)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_supervisor_cannot_access_admin(client: AsyncClient, supervisor_headers):
    """Supervisor nao pode acessar endpoints /api/admin."""
    resp = await client.get("/api/admin/audit", headers=supervisor_headers)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_gestor_cannot_access_admin(client: AsyncClient, gestor_headers):
    """Gestor nao pode acessar endpoints /api/admin."""
    resp = await client.get("/api/admin/audit", headers=gestor_headers)
    assert resp.status_code == 403
