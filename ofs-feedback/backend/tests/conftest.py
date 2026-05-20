"""
conftest.py — Fixtures globais para testes do Sistema OFS/OFS.

Fornece:
  - Motor de banco async de teste (PostgreSQL)
  - Sessao transacional (rollback automatico)
  - Cliente HTTP async (httpx.AsyncClient)
  - Headers de autenticacao por perfil
  - Dados de seed (empresas, usuarios, metas, OFSS)
"""

import asyncio
import os
from datetime import datetime, timezone, timedelta, date
from typing import AsyncGenerator
from uuid import uuid4, UUID

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

# ---------------------------------------------------------------------------
# Garantir env vars para testes (antes dos imports de app)
# ---------------------------------------------------------------------------
os.environ.setdefault("JWT_SECRET", "test-secret-key-at-least-32-chars-long-for-testing-only")
os.environ.setdefault("JWT_ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "15")
os.environ.setdefault("REFRESH_TOKEN_EXPIRE_DAYS", "7")
os.environ.setdefault("PASSWORD_EXPIRATION_DAYS", "90")
os.environ.setdefault("PASSWORD_HISTORY_COUNT", "5")
os.environ.setdefault("MAX_FAILED_ATTEMPTS", "5")
os.environ.setdefault("LOCKOUT_MINUTES", "30")
os.environ.setdefault("DB_HOST", "localhost")
os.environ.setdefault("DB_PORT", "5432")
os.environ.setdefault("DB_USER", "ofs_app")
os.environ.setdefault("DB_PASSWORD", "test_password")
os.environ.setdefault("DB_NAME", "ofs_feedback_test")

from app.main import app
from app.db.base import Base
from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, hash_password
from app.models.usuario import Usuario
from app.models.empresa import Empresa
from app.models.meta import Meta
from app.models.OFS import OFS, OFCEditLog
from app.models.auditoria import AuditoriaLog
from app.models.auth_models import LoginAttempt, RefreshToken, PasswordHistory

# ---------------------------------------------------------------------------
# Configuracao do banco de teste
# ---------------------------------------------------------------------------

# Usa a mesma base mas com sufixo _test; se nao houver acesso,
# usa SQLite em memoria como fallback
TEST_DB_URL = os.getenv(
    "TEST_DATABASE_URL",
    settings.database_url.replace("ofs_feedback", "ofs_feedback_test")
    if "ofs_feedback" in settings.database_url
    else "sqlite+aiosqlite:///:memory:",
)


@pytest.fixture(scope="session")
def event_loop():
    """Loop de eventos unico para toda a sessao de testes."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def test_engine():
    """Engine async para a sessao de testes."""
    if "sqlite" in TEST_DB_URL:
        engine = create_async_engine(TEST_DB_URL, echo=False)
    else:
        engine = create_async_engine(TEST_DB_URL, echo=False, pool_size=5)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture(scope="session")
async def _create_tables(test_engine):
    """Cria todas as tabelas uma vez antes dos testes."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


async def _run_seed(db: AsyncSession):
    """Popula tabelas basicas para uso em todos os testes."""
    empresas = [
        Empresa(id=UUID("a0000000-0000-0000-0000-000000000001"), nome="Security Dynamics Ltda.", cnpj="00.000.000/0001-01", ativo=True),
        Empresa(id=UUID("a0000000-0000-0000-0000-000000000002"), nome="G4S Brasil", cnpj="00.000.000/0001-02", ativo=True),
        Empresa(id=UUID("a0000000-0000-0000-0000-000000000003"), nome="ERA Seguranca", cnpj="00.000.000/0001-03", ativo=True),
    ]
    for e in empresas:
        db.add(e)

    # Usuarios de teste (senha: "Teste@123" para todos)
    pw_hash = hash_password("Teste@123")
    usuarios = [
        Usuario(
            id=UUID("b0000000-0000-0000-0000-000000000001"),
            username="admin",
            password_hash=pw_hash,
            nome="Administrador do Sistema",
            email="admin@securitydynamics.com.br",
            perfil="admin",
            empresa_id=UUID("a0000000-0000-0000-0000-000000000001"),
            empresa_nome="Security Dynamics Ltda.",
            ativo=True,
        ),
        Usuario(
            id=UUID("b0000000-0000-0000-0000-000000000002"),
            username="gestor",
            password_hash=pw_hash,
            nome="Gestor de Operacoes",
            email="gestor@securitydynamics.com.br",
            perfil="gestor",
            empresa_id=UUID("a0000000-0000-0000-0000-000000000001"),
            empresa_nome="Security Dynamics Ltda.",
            ativo=True,
        ),
        Usuario(
            id=UUID("b0000000-0000-0000-0000-000000000003"),
            username="supervisor",
            password_hash=pw_hash,
            nome="Supervisor de Area",
            email="supervisor@securitydynamics.com.br",
            perfil="supervisor",
            empresa_id=UUID("a0000000-0000-0000-0000-000000000001"),
            empresa_nome="Security Dynamics Ltda.",
            ativo=True,
        ),
        Usuario(
            id=UUID("b0000000-0000-0000-0000-000000000004"),
            username="observador",
            password_hash=pw_hash,
            nome="Observador de Campo",
            email="observador@securitydynamics.com.br",
            perfil="observador",
            empresa_id=UUID("a0000000-0000-0000-0000-000000000001"),
            empresa_nome="Security Dynamics Ltda.",
            ativo=True,
        ),
        Usuario(
            id=UUID("b0000000-0000-0000-0000-000000000005"),
            username="supervisor_g4s",
            password_hash=pw_hash,
            nome="Supervisor G4S",
            email="supervisor@g4s.com.br",
            perfil="supervisor",
            empresa_id=UUID("a0000000-0000-0000-0000-000000000002"),
            empresa_nome="G4S Brasil",
            ativo=True,
        ),
        Usuario(
            id=UUID("b0000000-0000-0000-0000-000000000006"),
            username="observador_inativo",
            password_hash=pw_hash,
            nome="Observador Inativo",
            email="inativo@securitydynamics.com.br",
            perfil="observador",
            empresa_id=UUID("a0000000-0000-0000-0000-000000000001"),
            empresa_nome="Security Dynamics Ltda.",
            ativo=False,
        ),
    ]
    for u in usuarios:
        db.add(u)

    # Meta vigente
    db.add(Meta(
        id=UUID("c0000000-0000-0000-0000-000000000001"),
        empresa_id=UUID("a0000000-0000-0000-0000-000000000001"),
        contrato_id=None,
        pessoas_ativas=50,
        meta_diaria=5,
        meta_semanal=250,
        vigencia_inicio=date.today() - timedelta(days=30),
        ativo=True,
    ))

    await db.flush()


@pytest_asyncio.fixture(scope="function")
async def db_session(test_engine, _create_tables) -> AsyncGenerator[AsyncSession, None]:
    """Sessao transacional por funcao de teste (rollback ao final)."""
    connection = await test_engine.connect()
    trans = await connection.begin()
    session_factory = async_sessionmaker(
        bind=connection,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        await _run_seed(session)
        await session.flush()
        yield session
    await trans.rollback()
    await connection.close()


@pytest_asyncio.fixture(scope="function")
async def db_session_empty(test_engine, _create_tables) -> AsyncGenerator[AsyncSession, None]:
    """Sessao sem dados de seed (para testes que precisam de DB vazio)."""
    connection = await test_engine.connect()
    trans = await connection.begin()
    session_factory = async_sessionmaker(
        bind=connection,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        yield session
    await trans.rollback()
    await connection.close()


# ---------------------------------------------------------------------------
# Tokens JWT por perfil
# ---------------------------------------------------------------------------

ADMIN_ID = "b0000000-0000-0000-0000-000000000001"
GESTOR_ID = "b0000000-0000-0000-0000-000000000002"
SUPERVISOR_ID = "b0000000-0000-0000-0000-000000000003"
OBSERVADOR_ID = "b0000000-0000-0000-0000-000000000004"
SUPERVISOR_G4S_ID = "b0000000-0000-0000-0000-000000000005"
INATIVO_ID = "b0000000-0000-0000-0000-000000000006"


def _make_token(user_id: str, perfil: str) -> str:
    return create_access_token(user_id, perfil)


@pytest.fixture(scope="session")
def admin_token() -> str:
    return _make_token(ADMIN_ID, "admin")


@pytest.fixture(scope="session")
def gestor_token() -> str:
    return _make_token(GESTOR_ID, "gestor")


@pytest.fixture(scope="session")
def supervisor_token() -> str:
    return _make_token(SUPERVISOR_ID, "supervisor")


@pytest.fixture(scope="session")
def observador_token() -> str:
    return _make_token(OBSERVADOR_ID, "observador")


@pytest.fixture(scope="session")
def supervisor_g4s_token() -> str:
    return _make_token(SUPERVISOR_G4S_ID, "supervisor")


@pytest.fixture(scope="session")
def inativo_token() -> str:
    return _make_token(INATIVO_ID, "observador")


@pytest.fixture(scope="session")
def expired_token() -> str:
    """Token JWT ja expirado (iat ha 2 dias, exp ha 1 dia)."""
    from jose import jwt
    now = datetime.now(timezone.utc)
    payload = {
        "sub": OBSERVADOR_ID,
        "perfil": "observador",
        "type": "access",
        "exp": now - timedelta(days=1),
        "iat": now - timedelta(days=2),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


# ---------------------------------------------------------------------------
# Headers de autenticacao por perfil (conveniencia)
# ---------------------------------------------------------------------------

@pytest.fixture
def admin_headers(admin_token: str) -> dict:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture
def gestor_headers(gestor_token: str) -> dict:
    return {"Authorization": f"Bearer {gestor_token}"}


@pytest.fixture
def supervisor_headers(supervisor_token: str) -> dict:
    return {"Authorization": f"Bearer {supervisor_token}"}


@pytest.fixture
def observador_headers(observador_token: str) -> dict:
    return {"Authorization": f"Bearer {observador_token}"}


@pytest.fixture
def supervisor_g4s_headers(supervisor_g4s_token: str) -> dict:
    return {"Authorization": f"Bearer {supervisor_g4s_token}"}


@pytest.fixture
def expired_headers(expired_token: str) -> dict:
    return {"Authorization": f"Bearer {expired_token}"}


# ---------------------------------------------------------------------------
# Cliente HTTP async
# ---------------------------------------------------------------------------

@pytest_asyncio.fixture(scope="function")
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Cliente HTTP assincrono usando ASGI transport (sem subir servidor real)."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ---------------------------------------------------------------------------
# Factory helpers para criar dados nos testes
# ---------------------------------------------------------------------------

@pytest.fixture
def valid_ofc_payload() -> dict:
    """Payload valido para criacao de OFS."""
    return {
        "data": date.today().isoformat(),
        "hora": "14:30",
        "nome_observado": "Joao Silva Santos",
        "atividade": "Operacao de empilhadeira no armazem B",
        "local": "Armazem B",
        "turno": "1",
        "tipo": "OFS",
        "comportamento": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota e colete.",
        "observacao": "Operador demonstrou atencao redobrada aos procedimentos.",
        "contrato_nome": "Operacao Security Dynamics",
    }


@pytest.fixture
def valid_ofs_payload() -> dict:
    """Payload valido para criacao de OFS (desvio/inseguro)."""
    return {
        "data": date.today().isoformat(),
        "hora": "10:15",
        "nome_observado": "Maria Souza",
        "atividade": "Limpeza de maquinas na linha de producao",
        "local": "Linha 3",
        "turno": "2",
        "tipo": "OFS",
        "comportamento": "Operador nao utilizava luva de protecao durante a limpeza quimica.",
        "observacao": "Orientado e corrigido no momento.",
        "contrato_nome": "Operacao Security Dynamics",
    }


@pytest.fixture
def minimal_ofc_payload() -> dict:
    """Payload minimo valido (apenas campos obrigatorios)."""
    return {
        "data": date.today().isoformat(),
        "hora": "08:00",
        "nome_observado": "Pedro",
        "atividade": "Controle",
        "local": "Portaria",
        "turno": "ADM",
        "tipo": "OFS",
        "comportamento": "Comportamento seguro observado durante a atividade.",
    }


@pytest_asyncio.fixture
async def created_ofc(client, observador_headers, valid_ofc_payload, db_session) -> UUID:
    """Cria um OFS e retorna seu ID."""
    resp = await client.post("/api/OFS-records", json=valid_ofc_payload, headers=observador_headers)
    assert resp.status_code == 201
    return UUID(resp.json()["id"])


@pytest_asyncio.fixture
async def created_ofc_gestor(client, gestor_headers, valid_ofc_payload) -> UUID:
    """Cria um OFS com o perfil gestor e retorna seu ID."""
    resp = await client.post("/api/OFS-records", json=valid_ofc_payload, headers=gestor_headers)
    assert resp.status_code == 201
    return UUID(resp.json()["id"])


# ---------------------------------------------------------------------------
# Mock de get_db para testes que precisam injetar sessao
# ---------------------------------------------------------------------------

@pytest.fixture
def override_get_db(db_session):
    """Override da dependencia get_db para usar a sessao de teste."""
    from app.db.session import get_db

    async def _override():
        yield db_session

    app.dependency_overrides[get_db] = _override
    yield
    app.dependency_overrides.pop(get_db, None)
