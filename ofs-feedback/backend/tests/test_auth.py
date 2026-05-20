"""
test_auth.py — Testes de autenticacao (login, logout, refresh, lockout).

Cenarios:
  1. Login valido -> 200 + tokens
  2. Login credenciais invalidas -> 401
  3. Usuario inativo -> 403
  4. Lockout apos 5 falhas -> 423
  5. Refresh token valido -> 200
  6. Refresh com token expirado -> 401
  7. Logout -> 200
  8. Acesso sem token -> 401
  9. Acesso com token expirado -> 401
 10. Login com senha expirada -> 403
"""

import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4

from httpx import AsyncClient

from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.models.usuario import Usuario
from app.models.auth_models import LoginAttempt


# ---------------------------------------------------------------------------
# 1. Login valido -> 200 + tokens
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    """Login com credenciais validas retorna 200, access_token e refresh_token."""
    resp = await client.post("/api/auth/login", data={
        "username": "observador",
        "password": "Teste@123",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["username"] == "observador"
    assert data["user"]["perfil"] == "observador"


# ---------------------------------------------------------------------------
# 2. Login invalido -> 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_invalid_credentials(client: AsyncClient):
    """Credenciais invalidas retornam 401."""
    resp = await client.post("/api/auth/login", data={
        "username": "observador",
        "password": "senha_errada",
    })
    assert resp.status_code == 401
    assert "Credenciais invalidas" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_login_nonexistent_user(client: AsyncClient):
    """Usuario inexistente retorna 401."""
    resp = await client.post("/api/auth/login", data={
        "username": "nao_existe",
        "password": "Teste@123",
    })
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 3. Usuario inativo -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_inactive_user(client: AsyncClient):
    """Usuario com ativo=False retorna 403."""
    resp = await client.post("/api/auth/login", data={
        "username": "observador_inativo",
        "password": "Teste@123",
    })
    assert resp.status_code == 403
    assert "desativado" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# 4. Lockout apos 5 falhas -> 423
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_lockout_after_failed_attempts(client: AsyncClient, db_session):
    """Apos 5 tentativas falhas, conta e bloqueada (423)."""
    username = "observador"

    # 4 falhas -> 401
    for i in range(4):
        resp = await client.post("/api/auth/login", data={
            "username": username,
            "password": "errada",
        })
        assert resp.status_code == 401, f"Tentativa {i + 1} deveria ser 401"

    # Registrar 5a tentativa manualmente para garantir lockout
    db_session.add(LoginAttempt(
        username=username,
        success=False,
        failure_reason="invalid_credentials",
        created_at=datetime.now(timezone.utc),
    ))
    await db_session.flush()

    # 6a tentativa (5 falhas acumuladas) -> 423
    resp = await client.post("/api/auth/login", data={
        "username": username,
        "password": "errada",
    })
    assert resp.status_code == 423
    assert "bloqueada" in resp.json()["detail"].lower() or "bloqueado" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# 5. Refresh token -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_refresh_token_success(client: AsyncClient):
    """Refresh com token valido retorna novo par de tokens."""
    # Primeiro faz login para obter refresh_token
    login_resp = await client.post("/api/auth/login", data={
        "username": "observador",
        "password": "Teste@123",
    })
    refresh_token = login_resp.json()["refresh_token"]

    resp = await client.post("/api/auth/refresh", json={"refresh_token": refresh_token})
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["refresh_token"] != refresh_token  # deve ser rotacionado


# ---------------------------------------------------------------------------
# 6. Refresh com token expirado -> 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_refresh_token_invalid_junk(client: AsyncClient):
    """Refresh com token invalido (texto qualquer) retorna 401."""
    resp = await client.post("/api/auth/refresh", json={
        "refresh_token": "jwt_token_totalmente_invalido_e_nao_decodificavel",
    })
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_refresh_token_invalid(client: AsyncClient):
    """Refresh com token invalido (lixo) retorna 401."""
    resp = await client.post("/api/auth/refresh", json={"refresh_token": "token_invalido"})
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 7. Logout -> 200
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_logout_success(client: AsyncClient, observador_headers):
    """Logout com token valido retorna 200 e mensagem de sucesso."""
    resp = await client.post("/api/auth/logout", headers=observador_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "sucesso" in data["message"].lower()


# ---------------------------------------------------------------------------
# 8. Acesso sem token -> 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_access_without_token(client: AsyncClient):
    """Requisicao a endpoint protegido sem token retorna 401."""
    resp = await client.get("/api/OFS-records")
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 9. Acesso com token expirado -> 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_access_with_expired_token(client: AsyncClient, expired_headers):
    """Token JWT expirado retorna 401."""
    resp = await client.get("/api/OFS-records", headers=expired_headers)
    assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 10. Login com senha expirada -> 403
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_login_expired_password(client: AsyncClient, db_session):
    """Usuario com senha expirada retorna 403."""
    # Atualiza password_changed_at para 120 dias atras
    from sqlalchemy import update
    await db_session.execute(
        update(Usuario)
        .where(Usuario.username == "observador")
        .values(password_changed_at=datetime.now(timezone.utc) - timedelta(days=100))
    )
    await db_session.flush()

    resp = await client.post("/api/auth/login", data={
        "username": "observador",
        "password": "Teste@123",
    })
    assert resp.status_code == 403
    assert "expirada" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Auxiliar: criar refresh token expirado
# ---------------------------------------------------------------------------

@pytest.fixture
def expired_refresh_token_str() -> str:
    """Gera um refresh token JWT ja expirado."""
    from jose import jwt
    from app.core.config import settings as s
    now = datetime.now(timezone.utc)
    payload = {
        "sub": "b0000000-0000-0000-0000-000000000004",
        "type": "refresh",
        "exp": now - timedelta(days=1),
        "iat": now - timedelta(days=8),
    }
    return jwt.encode(payload, s.JWT_SECRET, algorithm=s.JWT_ALGORITHM)


@pytest.mark.asyncio
async def test_refresh_with_expired_token(client: AsyncClient, expired_refresh_token_str):
    """Refresh com token JWT expirado retorna 401."""
    resp = await client.post("/api/auth/refresh", json={"refresh_token": expired_refresh_token_str})
    assert resp.status_code == 401
