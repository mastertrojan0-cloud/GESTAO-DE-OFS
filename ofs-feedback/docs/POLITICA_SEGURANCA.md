# Política de Segurança da Informação — Sistema OFS/OFS

**Security Dynamics — Sistema de Feedback Comportamental**  
**Versão:** 1.0 | **Classificação:** CONFIDENCIAL | **Data:** 2026-05-13

---

## Sumário

1. [Política de Controle de Acesso (RBAC)](#1-política-de-controle-de-acesso-rbac)
2. [Política de Senhas e Autenticação](#2-política-de-senhas-e-autenticação)
3. [Rastreabilidade e Auditoria](#3-rastreabilidade-e-auditoria)
4. [Política de Edição e Cancelamento](#4-política-de-edição-e-cancelamento)
5. [Segurança da Aplicação](#5-segurança-da-aplicação)
6. [Estratégia de Backup e Recuperação](#6-estratégia-de-backup-e-recuperação)
7. [Recomendações de Hardening](#7-recomendações-de-hardening)
8. [Conformidade (Opcional Futuro)](#8-conformidade-opcional-futuro)

---

## 1. Política de Controle de Acesso (RBAC)

### 1.1 Definição dos Perfis

| Perfil | Descrição |
|--------|-----------|
| **Observador** | Usuário operacional que registra OFS/OFS. Visualiza apenas seus próprios registros. |
| **Supervisor** | Responsável por uma empresa. Visualiza dados de toda sua empresa, pode editar OFCs em até 48h. |
| **Gestor** | Gerente regional/corporativo. Acesso a múltiplas empresas, relatórios, gestão de usuários da sua empresa. |
| **Admin** | Administrador do sistema. Acesso total, auditoria, backup/restore, gestão de empresas. |

### 1.2 Matriz de Permissões Completa

| Recurso/Ação | Observador | Supervisor | Gestor | Admin |
|---|---|---|---|---|
| **OFS/OFS** |||||
| Criar OFS | ✅ (próprio) | ✅ (próprio) | ✅ | ✅ |
| Ver OFS | ✅ (apenas seus) | ✅ (sua empresa) | ✅ (todas) | ✅ (todas) |
| Editar OFS | ✅ (seu, até 24h) | ✅ (empresa, até 48h) | ✅ (sem limite) | ✅ (sem limite) |
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Exportar CSV | ✅ (seus) | ✅ (sua empresa) | ✅ (todas) | ✅ (todas) |
| **Métricas** |||||
| Ver métricas | ❌ | ✅ (sua empresa) | ✅ (todas) | ✅ (todas) |
| Ver gráficos | ❌ | ✅ (sua empresa) | ✅ (todas) | ✅ (todas) |
| **Relatórios PDF** |||||
| Gerar PDF individual | ✅ (seus) | ✅ (empresa) | ✅ | ✅ |
| Gerar PDF semanal | ❌ | ❌ | ✅ | ✅ |
| Gerar PDF mensal | ❌ | ❌ | ✅ | ✅ |
| **Administração** |||||
| Gerenciar usuários | ❌ | ❌ | ✅ (sua empresa) | ✅ (todos) |
| Gerenciar empresas | ❌ | ❌ | ❌ | ✅ |
| Gerenciar contratos | ❌ | ❌ | ✅ (sua empresa) | ✅ (todos) |
| Gerenciar metas | ❌ | ❌ | ✅ (sua empresa) | ✅ (todos) |
| Ver auditoria | ❌ | ❌ | ❌ | ✅ |
| Backup/Restore | ❌ | ❌ | ❌ | ✅ |

### 1.3 Regras de Escopo de Dados (Data Scoping)

Cada perfil possui um escopo de visibilidade que deve ser aplicado no nível da query SQL:

```python
SCOPE_FILTERS = {
    "observador": "WHERE generated_by = :user_id AND is_deleted = FALSE",
    "supervisor": "WHERE company_id = :company_id AND is_deleted = FALSE",
    "gestor":     "WHERE is_deleted = FALSE",       # todas as empresas (filtrável por parâmetro)
    "admin":      ""                                 # sem restrição (inclui deletados se solicitado)
}
```

**Regra complementar para Gestor:** Quando o Gestor gerencia usuários/metas, o escopo é restrito à empresa. Para visualização de OFCs e métricas, o escopo é amplo.

| Contexto | Escopo do Gestor |
|----------|-------------------|
| Ver/Exportar OFCs | Todas as empresas |
| Ver métricas/gráficos | Todas as empresas |
| Gerenciar usuários | Sua empresa apenas |
| Gerenciar metas | Sua empresa apenas |
| Gerenciar contratos | Sua empresa apenas |

### 1.4 Implementação Técnica no FastAPI

```python
# backend/app/core/security.py

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from uuid import UUID
from typing import Callable

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Decodifica JWT e retorna usuário autenticado."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido ou expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = await db.get(User, UUID(user_id))
    if user is None or not user.ativo:
        raise credentials_exception
    return user


def require_role(*roles: str) -> Callable:
    """Dependency que exige um ou mais perfis."""
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.perfil not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Seu perfil não tem permissão para esta ação."
            )
        return current_user
    return role_checker


def require_ofc_access(ofc_id: UUID) -> Callable:
    """Dependency que verifica se o usuário pode acessar um OFS específico."""
    async def access_checker(
        ofc_id: UUID = ofc_id,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
    ) -> OFS:
        OFS = await db.get(OFS, ofc_id)
        if OFS is None or OFS.is_deleted:
            raise HTTPException(status_code=404, detail="OFS não encontrada.")

        if current_user.perfil == "observador" and OFS.generated_by != current_user.id:
            raise HTTPException(status_code=403, detail="Sem acesso a este registro.")
        if current_user.perfil == "supervisor" and OFS.company_id != current_user.company_id:
            raise HTTPException(status_code=403, detail="Sem acesso a registros de outra empresa.")
        # gestor e admin têm acesso a qualquer OFS

        return OFS
    return access_checker


def get_data_scope(current_user: User) -> dict:
    """Retorna filtro SQLAlchemy baseado no perfil do usuário."""
    if current_user.perfil == "observador":
        return {"generated_by": current_user.id, "is_deleted": False}
    elif current_user.perfil == "supervisor":
        return {"company_id": current_user.company_id, "is_deleted": False}
    elif current_user.perfil == "gestor":
        return {"is_deleted": False}
    else:  # admin
        return {}
```

**Uso em endpoints:**

```python
# backend/app/api/OFS.py

@router.get("/OFS", response_model=PaginatedResponse[OFCOut])
async def list_ofc(
    filters: OFCFiltros = Depends(),
    current_user: User = Depends(require_role("observador", "supervisor", "gestor", "admin")),
    db: AsyncSession = Depends(get_db)
):
    scope = get_data_scope(current_user)
    query = select(OFS).filter_by(**scope)
    # ... aplicar filtros adicionais do usuário
    return paginated_result


@router.put("/OFS/{ofc_id}", response_model=OFCOut)
async def update_ofc(
    OFS: OFS = Depends(require_ofc_access(ofc_id)),
    payload: OFCUpdate,
    current_user: User = Depends(require_role("observador", "supervisor", "gestor", "admin")),
    db: AsyncSession = Depends(get_db)
):
    # Verificação de janela de edição
    check_edit_window(OFS, current_user)
    # ... aplicar alterações
    return updated_ofc
```

---

## 2. Política de Senhas e Autenticação

### 2.1 Requisitos de Senha

| Critério | Valor |
|----------|-------|
| Comprimento mínimo | 8 caracteres |
| Letra maiúscula | Mínimo 1 |
| Letra minúscula | Mínimo 1 |
| Número | Mínimo 1 |
| Caractere especial | Opcional (não obrigatório) |
| Hash | bcrypt com cost factor 12 |
| Expiração | 90 dias (configurável via `PASSWORD_EXPIRATION_DAYS`) |
| Histórico | Não reutilizar últimas 5 senhas |
| Bloqueio | 5 tentativas falhas → bloqueio de 30 minutos |
| Recuperação | Somente via Admin (sistema intranet, sem e-mail externo) |

**Validação de senha (Pydantic):**

```python
# backend/app/schemas/auth.py
import re
from pydantic import BaseModel, field_validator

class PasswordChange(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Senha deve ter no mínimo 8 caracteres.")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Senha deve conter ao menos 1 letra maiúscula.")
        if not re.search(r"[a-z]", v):
            raise ValueError("Senha deve conter ao menos 1 letra minúscula.")
        if not re.search(r"\d", v):
            raise ValueError("Senha deve conter ao menos 1 número.")
        return v
```

**Hash e verificação:**

```python
# backend/app/core/security.py
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], bcrypt__rounds=12, deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)
```

**Verificação de histórico de senhas:**

```python
async def is_password_reused(user_id: UUID, new_password: str, db: AsyncSession) -> bool:
    """Verifica se a nova senha está entre as últimas 5 do histórico."""
    recent_hashes = await db.execute(
        select(PasswordHistory.password_hash)
        .where(PasswordHistory.user_id == user_id)
        .order_by(PasswordHistory.created_at.desc())
        .limit(5)
    )
    for (pw_hash,) in recent_hashes:
        if pwd_context.verify(new_password, pw_hash):
            return True
    return False
```

**Bloqueio por tentativas:**

```python
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_MINUTES = 30

async def check_login_lockout(username: str, db: AsyncSession) -> None:
    recent_failures = await db.execute(
        select(func.count(LoginAttempt.id))
        .where(
            LoginAttempt.username == username,
            LoginAttempt.success == False,
            LoginAttempt.created_at > datetime.utcnow() - timedelta(minutes=LOCKOUT_MINUTES)
        )
    )
    if recent_failures.scalar() >= MAX_FAILED_ATTEMPTS:
        raise HTTPException(
            status_code=423,
            detail=f"Conta bloqueada temporariamente. Tente novamente em {LOCKOUT_MINUTES} minutos."
        )
```

### 2.2 JWT Configuration

| Parâmetro | Valor | Justificativa |
|-----------|-------|---------------|
| Access Token TTL | 15 minutos | Curto o suficiente para mitigar roubo; intranet é ambiente controlado |
| Refresh Token TTL | 7 dias | Permite sessão longa sem re-login; revogável no servidor |
| Algoritmo | HS256 | Simétrico, adequado para backend monolítico (único emissor/validador) |
| Secret | Mínimo 256 bits (32 bytes) | Armazenado em variável de ambiente `JWT_SECRET` |
| Blacklist | Tabela `revoked_tokens` | Refresh tokens revogados no logout |
| Limpeza | Cronjob diário às 02:00 | Remove tokens expirados da blacklist |

**Configuração (settings):**

```python
# backend/app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    JWT_SECRET: str                        # ex: openssl rand -hex 32
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    PASSWORD_EXPIRATION_DAYS: int = 90

    class Config:
        env_file = ".env"
```

**Geração e validação de tokens:**

```python
from jose import jwt
from datetime import datetime, timedelta

def create_access_token(user_id: str, perfil: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": user_id,
        "perfil": perfil,
        "type": "access",
        "exp": expire,
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": user_id,
        "type": "refresh",
        "exp": expire,
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
```

**Validação com verificação de revogação:**

```python
async def validate_access_token(token: str, db: AsyncSession) -> dict:
    """Valida access token verificando também blacklist."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Tipo de token inválido.")
        # Verificar se o refresh token associado foi revogado
        # (access token é short-lived; verificamos blacklist no refresh)
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado.")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido.")
```

### 2.3 Proteção de Sessão

**Decisão de armazenamento:**

| Token | Onde armazenar | Justificativa |
|-------|---------------|---------------|
| Access Token | Memória (variável JS) | Não persiste após fechar aba; protege contra XSS |
| Refresh Token | httpOnly Secure Cookie | Inacessível via JS; protege contra XSS |

> **Nota para intranet com HTTP:** Se HTTPS não estiver disponível no MVP, `Secure` flag será omitida. Aplicar assim que HTTPS for implementado. Enquanto HTTP, usar localStorage com rotação curta de access token como mitigação.

**Logout (revogação server-side):**

```python
@router.post("/auth/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Revoga todos os refresh tokens do usuário
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == current_user.id, RefreshToken.revoked == False)
        .values(revoked=True, revoked_at=datetime.utcnow())
    )
    await db.commit()
    return {"message": "Logout realizado com sucesso."}
```

**Proteção CSRF:**
- API REST usa header `Authorization: Bearer <token>` — não depende de cookies para autenticação principal
- Refresh token em cookie usa `SameSite=Lax`

---

## 3. Rastreabilidade e Auditoria

### 3.1 Eventos Auditáveis

| # | Evento | Severidade | Dados Registrados |
|---|--------|-----------|-------------------|
| 1 | `LOGIN_SUCCESS` | INFO | user_id, username, ip, user_agent, timestamp |
| 2 | `LOGIN_FAILED` | WARNING | username, ip, reason, user_agent |
| 3 | `LOGOUT` | INFO | user_id, username, timestamp, ip |
| 4 | `TOKEN_REFRESH` | INFO | user_id, username, timestamp, ip |
| 5 | `PASSWORD_CHANGE` | WARNING | user_id, username, ip |
| 6 | `OFC_CREATE` | INFO | user_id, ofc_id, company_id, tipo (OFS/OFS) |
| 7 | `OFC_UPDATE` | WARNING | user_id, ofc_id, campos_alterados (JSONB), ip |
| 8 | `OFC_CANCEL` | WARNING | user_id, ofc_id, cancelado_por, motivo |
| 9 | `OFC_EXPORT` | INFO | user_id, filtros_usados, quantidade_registros |
| 10 | `REPORT_GENERATE` | INFO | user_id, tipo_relatorio, parametros (JSONB) |
| 11 | `USER_CREATE` | WARNING | admin_id, new_user_id, perfil, empresa |
| 12 | `USER_UPDATE` | WARNING | admin_id, target_user_id, campos_alterados (JSONB) |
| 13 | `USER_DISABLE` | WARNING | admin_id, target_user_id |
| 14 | `USER_ENABLE` | WARNING | admin_id, target_user_id |
| 15 | `COMPANY_CREATE` | WARNING | user_id, company_id, nome |
| 16 | `COMPANY_UPDATE` | WARNING | user_id, company_id, campos_alterados |
| 17 | `CONTRACT_CREATE` | WARNING | user_id, contract_id, company_id |
| 18 | `CONTRACT_UPDATE` | WARNING | user_id, contract_id, campos_alterados |
| 19 | `TARGET_CREATE` | WARNING | user_id, target_id, company_id |
| 20 | `TARGET_UPDATE` | WARNING | user_id, target_id, old_values, new_values (JSONB) |
| 21 | `BACKUP_MANUAL` | INFO | user_id, filename, tamanho |
| 22 | `BACKUP_RESTORE` | CRITICAL | user_id, backup_id, filename |
| 23 | `PERMISSION_DENIED` | WARNING | user_id (se autenticado), recurso, acao_tentada, ip |
| 24 | `SESSION_EXPIRED` | INFO | user_id, username, timestamp |

### 3.2 Estrutura do Log de Auditoria

```sql
CREATE TABLE audit_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id       UUID REFERENCES usuarios(id),
    username      VARCHAR(100),
    full_name     VARCHAR(200),
    role          VARCHAR(20),                         -- perfil do usuário no momento

    action        VARCHAR(50) NOT NULL,                -- LOGIN_SUCCESS, OFC_CREATE, etc.
    resource      VARCHAR(50) NOT NULL,                -- OFS, USER, COMPANY, AUTH, etc.
    resource_id   UUID,                                -- ID do recurso afetado (opcional)

    details       JSONB DEFAULT '{}',                  -- campos alterados, filtros, parâmetros
    ip_address    INET,                                -- endereço IP de origem
    user_agent    TEXT,                                 -- User-Agent header

    severity      VARCHAR(10) NOT NULL DEFAULT 'INFO'  -- INFO, WARNING, CRITICAL
);

-- Índices para consulta eficiente
CREATE INDEX idx_audit_timestamp   ON audit_logs (created_at DESC);
CREATE INDEX idx_audit_user        ON audit_logs (user_id);
CREATE INDEX idx_audit_action      ON audit_logs (action);
CREATE INDEX idx_audit_resource    ON audit_logs (resource);
CREATE INDEX idx_audit_severity    ON audit_logs (severity);
CREATE INDEX idx_audit_user_action ON audit_logs (user_id, action);

-- Retenção: 2 anos
-- Configurável via AUDIT_RETENTION_DAYS
```

### 3.3 Implementação

**Decorator de auditoria:**

```python
# backend/app/core/audit.py
from functools import wraps
from datetime import datetime
import json

def audit(action: str, resource: str, severity: str = "INFO"):
    """Decorator que registra ações no audit_log de forma assíncrona."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Resolve parâmetros
            request = kwargs.get("request") or next(
                (a for a in args if isinstance(a, Request)), None
            )
            current_user = kwargs.get("current_user")
            db = kwargs.get("db")

            # Executa ação
            result = await func(*args, **kwargs)

            # Registra auditoria de forma assíncrona (fire-and-forget)
            if db and current_user:
                log_entry = AuditLog(
                    user_id=current_user.id,
                    username=current_user.username,
                    full_name=current_user.nome,
                    role=current_user.perfil,
                    action=action,
                    resource=resource,
                    details=json.dumps(_extract_details(kwargs, result)),
                    ip_address=request.client.host if request else None,
                    user_agent=request.headers.get("user-agent") if request else None,
                    severity=severity,
                )
                db.add(log_entry)
                # Não dá await commit — middleware fará commit

            return result
        return wrapper
    return decorator
```

**Middleware de auditoria global:**

```python
# backend/app/middleware/audit.py
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request

class AuditMiddleware(BaseHTTPMiddleware):
    """Middleware que registra todas as requisições 403 (PERMISSION_DENIED)
    e captura IP/User-Agent para o contexto da requisição."""

    async def dispatch(self, request: Request, call_next):
        # Injeta IP e UA no request.state para uso nos decorators
        request.state.client_ip = request.client.host
        request.state.user_agent = request.headers.get("user-agent", "")

        response = await call_next(request)

        # Registra tentativas de acesso negado
        if response.status_code == 403:
            background_tasks = BackgroundTasks()
            # Registro assíncrono de PERMISSION_DENIED
            ...

        return response
```

**Limpeza de logs expirados (cronjob):**

```python
# Tarefa executada diariamente via APScheduler
async def cleanup_old_audit_logs():
    retention_days = settings.AUDIT_RETENTION_DAYS  # padrão 730 (2 anos)
    cutoff = datetime.utcnow() - timedelta(days=retention_days)
    async with get_session() as db:
        await db.execute(
            delete(AuditLog).where(AuditLog.created_at < cutoff)
        )
        await db.commit()
```

### 3.4 Consulta e Exportação

```python
# Endpoint exclusivo para Admin
@router.get("/admin/audit", response_model=PaginatedResponse[AuditLogOut])
async def list_audit_logs(
    action: Optional[str] = None,
    user_id: Optional[UUID] = None,
    resource: Optional[str] = None,
    severity: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    page: int = 1,
    limit: int = 50,
    current_user: User = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    query = select(AuditLog)
    if action:   query = query.where(AuditLog.action == action)
    if user_id:  query = query.where(AuditLog.user_id == user_id)
    if resource: query = query.where(AuditLog.resource == resource)
    if severity: query = query.where(AuditLog.severity == severity)
    if date_from: query = query.where(AuditLog.created_at >= date_from)
    if date_to:   query = query.where(AuditLog.created_at <= date_to)
    query = query.order_by(AuditLog.created_at.desc())
    return await paginate(query, page, limit)


@router.get("/admin/audit/export", response_class=StreamingResponse)
async def export_audit_csv(
    date_from: date,
    date_to: date,
    current_user: User = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """Exporta logs de auditoria em CSV para auditoria externa."""
    logs = await db.execute(
        select(AuditLog)
        .where(AuditLog.created_at.between(date_from, date_to))
        .order_by(AuditLog.created_at.desc())
    )
    # ... gerar CSV e retornar como streaming
```

---

## 4. Política de Edição e Cancelamento

### 4.1 Regras de Edição

| Perfil | Janela de Edição | Escopo |
|--------|-----------------|--------|
| Observador | 24 horas após criação | Apenas OFCs próprios |
| Supervisor | 48 horas após criação | OFCs da sua empresa |
| Gestor | Sem limite | Qualquer OFS |
| Admin | Sem limite | Qualquer OFS |

**Implementação da verificação de janela:**

```python
from datetime import datetime, timedelta

EDIT_WINDOWS = {
    "observador": timedelta(hours=24),
    "supervisor": timedelta(hours=48),
    "gestor":     None,  # sem limite
    "admin":      None,  # sem limite
}

def check_edit_window(OFS: OFS, user: User) -> None:
    """Verifica se o usuário ainda está dentro da janela de edição."""
    window = EDIT_WINDOWS.get(user.perfil)
    if window is None:
        return  # gestor e admin sem limite

    deadline = OFS.created_at + window
    if datetime.utcnow() > deadline:
        horas = window.total_seconds() / 3600
        raise HTTPException(
            status_code=403,
            detail=f"Janela de edição expirada ({int(horas)}h após criação)."
        )
```

**Registro de edições (histórico de alterações):**

Cada edição deve registrar na tabela `ofc_edit_log`:

```sql
CREATE TABLE ofc_edit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ofc_id          UUID NOT NULL REFERENCES ofcs(id) ON DELETE CASCADE,
    campo           VARCHAR(100) NOT NULL,   -- nome do campo alterado
    valor_anterior  TEXT,                     -- valor antes da edição
    valor_novo      TEXT,                     -- valor após edição
    editado_por     UUID NOT NULL REFERENCES usuarios(id),
    editado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ofc_edit_log_ofc_id ON ofc_edit_log(ofc_id);
```

**OFS editada muda status para 'editado':**

```python
async def update_ofc(OFS: OFS, payload: OFCUpdate, user: User, db: AsyncSession):
    for campo, valor_novo in payload.dict(exclude_unset=True).items():
        valor_anterior = getattr(OFS, campo)
        if str(valor_anterior) != str(valor_novo):
            db.add(OFCEditLog(
                ofc_id=OFS.id,
                campo=campo,
                valor_anterior=str(valor_anterior),
                valor_novo=str(valor_novo),
                editado_por=user.id,
            ))
            setattr(OFS, campo, valor_novo)

    OFS.status = 'editado'
    OFS.updated_at = datetime.utcnow()
    OFS.editado_por = user.id
    OFS.editado_em = datetime.utcnow()
    await db.commit()
```

### 4.2 Regras de Cancelamento

| Ação | Observador | Supervisor | Gestor | Admin |
|------|-----------|------------|--------|-------|
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Reativar OFS cancelada | ❌ | ❌ | ❌ | ✅ |

**Implementação do cancelamento (soft delete):**

```python
@router.delete("/OFS/{ofc_id}")
@audit(action="OFC_CANCEL", resource="OFS", severity="WARNING")
async def cancel_ofc(
    ofc_id: UUID,
    motivo: str = Body(..., embed=True, min_length=10),
    current_user: User = Depends(require_role("gestor", "admin")),
    db: AsyncSession = Depends(get_db)
):
    OFS = await db.get(OFS, ofc_id)
    if not OFS:
        raise HTTPException(status_code=404, detail="OFS não encontrada.")
    if OFS.is_deleted:
        raise HTTPException(status_code=400, detail="OFS já está cancelada.")

    OFS.is_deleted = True
    OFS.motivo_cancelamento = motivo
    OFS.cancelado_por = current_user.id
    OFS.cancelado_em = datetime.utcnow()
    OFS.status = 'cancelado'

    await db.commit()
    return {"message": "OFS cancelada com sucesso."}
```

**Reativação (somente Admin):**

```python
@router.post("/OFS/{ofc_id}/restore")
@audit(action="OFC_RESTORE", resource="OFS", severity="WARNING")
async def restore_ofc(
    ofc_id: UUID,
    current_user: User = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    OFS = await db.get(OFS, ofc_id)
    if not OFS or not OFS.is_deleted:
        raise HTTPException(status_code=404, detail="OFS cancelada não encontrada.")

    OFS.is_deleted = False
    OFS.restaurado_por = current_user.id
    OFS.restaurado_em = datetime.utcnow()
    OFS.status = 'editado'  # marca como editado pois teve intervenção

    await db.commit()
    return {"message": "OFS restaurada com sucesso."}
```

### 4.3 Prevenção de Conflitos (Optimistic Locking)

**Mecanismo:** Antes de salvar uma edição, o backend verifica se o `updated_at` recebido do frontend coincide com o `updated_at` atual no banco. Se divergir, significa que outra edição ocorreu.

```python
@router.put("/OFS/{ofc_id}", response_model=OFCOut)
async def update_ofc(
    ofc_id: UUID,
    payload: OFCUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    OFS = await db.get(OFS, ofc_id)
    if not OFS:
        raise HTTPException(status_code=404)

    # Optimistic Locking Check
    if payload.updated_at and OFS.updated_at != payload.updated_at:
        raise HTTPException(
            status_code=409,
            detail="Este registro foi modificado por outro usuário. Recarregue os dados e tente novamente."
        )

    # ... aplicar alterações
```

**Schema de update deve incluir `updated_at`:**

```python
class OFCUpdate(BaseModel):
    comportamento: Optional[str] = None
    observacao: Optional[str] = None
    updated_at: datetime   # obrigatório para optimistic locking
```

---

## 5. Segurança da Aplicação

### 5.1 Proteções OWASP Top 10

#### A1: Broken Access Control
- RBAC implementado via `Depends(require_role(...))` em todos os endpoints protegidos
- Data scoping aplicado via `get_data_scope()` em todas as queries
- Verificação de propriedade de recurso via `require_ofc_access(ofc_id)`

#### A2: Cryptographic Failures
- Senhas: bcrypt cost factor 12
- JWT: HS256 com secret mínimo de 256 bits
- Database password e JWT_SECRET: exclusivamente em variáveis de ambiente
- `.env` no `.gitignore` e `.dockerignore`

#### A3: Injection
- **SQL Injection:** SQLAlchemy ORM com queries parametrizadas em 100% das operações
- **NoSQL Injection:** Não aplicável (PostgreSQL apenas)
- **Command Injection:** Nenhum `subprocess` com input do usuário

```python
# Exemplo de query parametrizada (nunca usar f-strings ou concatenação)
query = select(OFS).where(
    OFS.company_id == user.company_id,   # parâmetro bind automático
    OFS.turno == filters.turno,           # parâmetro bind automático
)
```

#### A4: Insecure Design
- Threat model: documentado neste documento
- Princípio do menor privilégio aplicado em todos os perfis
- Rate limiting por IP e por usuário

#### A5: Security Misconfiguration
- Security headers configurados no nginx
- Debug mode desabilitado em produção (`DEBUG=False`)
- CORS configurado estritamente (apenas origem do frontend)
- Erro 500 não expõe stack trace ao cliente

#### A6: Vulnerable Components
- Docker images com versionamento fixo (`python:3.12-slim`, não `python:latest`)
- Dependências Python com `requirements.txt` versionado
- Renovate/Dependabot para atualizações de segurança

#### A7: Authentication Failures
- Política de senhas robusta (Seção 2)
- Rate limiting no endpoint de login (5 tentativas/min por IP)
- Bloqueio após 5 falhas (30 minutos)
- JWT expiração curta (15 min)

#### A8: Software and Data Integrity
- Nenhum CDN externo (sistema intranet)
- npm packages auditados (`npm audit`)
- pip packages com hash verification

#### A9: Logging & Monitoring
- Todos os eventos de segurança são auditados (Seção 3)
- Logs de auditoria retidos por 2 anos
- Tentativas de acesso negado (403) são registradas

#### A10: SSRF
- Sistema intranet sem acesso externo
- Nenhum endpoint que aceita URL do usuário para fetch

### 5.2 Security Headers (Nginx)

```nginx
# nginx.conf
server {
    listen 80;

    # Security Headers
    add_header X-Content-Type-Options    "nosniff" always;
    add_header X-Frame-Options           "DENY" always;
    add_header X-XSS-Protection          "1; mode=block" always;
    add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy        "geolocation=(), microphone=(), camera=()" always;

    # CSP (Content-Security-Policy) — restritivo para intranet
    add_header Content-Security-Policy   "default-src 'self'; "
                                         "script-src 'self' 'unsafe-inline'; "
                                         "style-src 'self' 'unsafe-inline'; "
                                         "img-src 'self' data:; "
                                         "font-src 'self'; "
                                         "connect-src 'self'; "
                                         "frame-ancestors 'none'; "
                                         "form-action 'self';" always;

    # Remover header que expõe versão do servidor
    server_tokens off;

    location /api/ {
        proxy_pass http://backend:8000;
        # ... proxy settings
    }

    location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;
    }
}
```

### 5.3 Rate Limiting

```python
# backend/app/core/rate_limit.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])

# Endpoints sensíveis com limites mais restritivos
@router.post("/auth/login")
@limiter.limit("5/minute")  # 5 tentativas de login por minuto por IP
async def login(...):
    ...
```

### 5.4 Input Validation (Pydantic)

```python
from pydantic import BaseModel, field_validator, Field
from typing import Optional
import re

class OFCCreate(BaseModel):
    nome_observado: str = Field(..., min_length=3, max_length=200)
    atividade: str = Field(..., min_length=3, max_length=500)
    local: str = Field(..., min_length=2, max_length=200)
    turno: Turno
    tipo: TipoOFC
    comportamento: str = Field(..., max_length=2000)
    observacao: Optional[str] = Field(None, max_length=2000)
    contrato_id: Optional[UUID] = None

    @field_validator("nome_observado", "atividade", "local", "comportamento")
    @classmethod
    def sanitize_strings(cls, v: str) -> str:
        """Remove caracteres de controle e trim."""
        v = v.strip()
        # Remove null bytes, caracteres de controle (exceto \n, \r, \t)
        v = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', v)
        return v

    @field_validator("nome_observado")
    @classmethod
    def no_html(cls, v: str) -> str:
        if re.search(r'<[^>]*>', v):
            raise ValueError("Tags HTML não são permitidas.")
        return v
```

### 5.5 Proteção de Dados Sensíveis

- **Senhas:** Nunca logadas. Campo `password` excluído de `repr()` dos modelos.
- **JWT Secret:** Disponível apenas como variável de ambiente. Não hardcoded.
- **Database Password:** Apenas em `.env`. `.env` no `.gitignore`.
- **PDFs/CSVs:** Acesso exclusivo via endpoints autenticados. Não servidos estaticamente.

```python
class User(Base):
    __tablename__ = "usuarios"

    # ...

    def __repr__(self) -> str:
        return f"<User id={self.id} username={self.username}>"
        # NOTA: password_hash nunca aparece em repr()
```

### 5.6 HTTPS na Intranet

| Fase | Abordagem | Justificativa |
|------|-----------|---------------|
| **MVP (imediatamente)** | HTTP puro | Intranet confiável. Acesso restrito à rede corporativa. |
| **Curto prazo (1-2 meses)** | Certificado autoassinado no nginx | Camada adicional de proteção mesmo em rede interna. |
| **Médio prazo (3-6 meses)** | CA interna da empresa | Recomendado. Permite HTTPS com certificado confiável pela rede corporativa. |

**Configuração de HTTPS com certificado autoassinado:**

```nginx
server {
    listen 443 ssl;
    ssl_certificate     /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # HSTS (após validar HTTPS estável)
    add_header Strict-Transport-Security "max-age=31536000" always;
    # ...
}

server {
    listen 80;
    return 301 https://$host$request_uri;
}
```

---

## 6. Estratégia de Backup e Recuperação

### 6.1 Política de Backup

#### 6.1.1 Agendamento

| Tipo | Horário | Comando |
|------|---------|---------|
| Backup diário | 03:00 AM (horário local) | `pg_dump -Fc -f backups/daily/ofs_$(date +%Y%m%d).dump` |
| Backup semanal | Domingo 03:00 AM | Cópia do diário de domingo para `backups/weekly/` |
| Backup mensal | Dia 1 às 03:00 AM | Cópia do diário do dia 1 para `backups/monthly/` |

#### 6.1.2 Retenção

| Frequência | Retenção | Diretório |
|------------|----------|-----------|
| Diários | 30 backups (1 mês) | `backups/daily/` |
| Semanais | 12 backups (~3 meses) | `backups/weekly/` |
| Mensais | 12 backups (1 ano) | `backups/monthly/` |
| Manuais | 10 backups | `backups/manual/` |

#### 6.1.3 Script de Backup

```bash
#!/bin/bash
# backend/scripts/backup.sh

BACKUP_DIR="/app/backups"
DAILY_DIR="$BACKUP_DIR/daily"
WEEKLY_DIR="$BACKUP_DIR/weekly"
MONTHLY_DIR="$BACKUP_DIR/monthly"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="ofs_backup_${TIMESTAMP}.dump"
RETENTION_DAILY=30
RETENTION_WEEKLY=12
RETENTION_MONTHLY=12

mkdir -p "$DAILY_DIR" "$WEEKLY_DIR" "$MONTHLY_DIR"

# Executar backup
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -Fc \
    -v \
    -f "$DAILY_DIR/$FILENAME"

# Verificar integridade
PGPASSWORD="$DB_PASSWORD" pg_restore --list "$DAILY_DIR/$FILENAME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERRO: Backup corrompido - $FILENAME"
    exit 1
fi

echo "Backup criado com sucesso: $FILENAME"

# Copiar para semanal (domingo - day 0)
if [ $(date +%u) -eq 7 ]; then
    cp "$DAILY_DIR/$FILENAME" "$WEEKLY_DIR/$FILENAME"
fi

# Copiar para mensal (dia 1)
if [ $(date +%d) -eq 01 ]; then
    cp "$DAILY_DIR/$FILENAME" "$MONTHLY_DIR/$FILENAME"
fi

# Rotacionar backups antigos
find "$DAILY_DIR" -name "*.dump" -mtime +$RETENTION_DAILY -delete
find "$WEEKLY_DIR" -name "*.dump" -mtime +$((RETENTION_WEEKLY * 7)) -delete
find "$MONTHLY_DIR" -name "*.dump" -mtime +$((RETENTION_MONTHLY * 30)) -delete

echo "Rotação de backups concluída."

# Cópia para NAS (se configurado)
if [ -n "$NAS_BACKUP_PATH" ]; then
    cp "$DAILY_DIR/$FILENAME" "$NAS_BACKUP_PATH/daily/"
    echo "Cópia para NAS concluída."
fi
```

**Configuração no docker-compose (cron):**

```yaml
# docker-compose.yml excerpt
services:
  backup:
    image: postgres:16-alpine
    volumes:
      - ./backups:/app/backups
      - ./scripts/backup.sh:/app/backup.sh:ro
    environment:
      DB_HOST: db
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
      NAS_BACKUP_PATH: ${NAS_BACKUP_PATH:-}
    entrypoint: |
      sh -c '
        echo "0 3 * * * /app/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root
        crond -f -l 2
      '
```

### 6.2 Procedimento de Restauração

#### 6.2.1 Via Interface Admin (Recomendado)

```
1. Admin acessa /admin/backup
2. Visualiza lista de backups disponíveis (data, tamanho, status)
3. Seleciona backup desejado
4. Clica "Restaurar"
5. Sistema exibe modal de confirmação:
   - "ATENÇÃO: A restauração substituirá TODOS os dados atuais."
   - "Usuários serão desconectados durante o processo."
   - Campo para senha do Admin (confirmação adicional)
6. Backend:
   a. Ativa modo manutenção (retorna 503 para todas as rotas)
   b. Executa pg_restore
   c. Verifica integridade
   d. Desativa modo manutenção
   e. Registra no audit_log (BACKUP_RESTORE, CRITICAL)
7. Admin é notificado da conclusão
```

#### 6.2.2 Via Linha de Comando (Recuperação de Desastre)

```bash
# 1. Localizar backup
ls -la /app/backups/daily/

# 2. Restaurar
PGPASSWORD="$DB_PASSWORD" pg_restore \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v \
    --clean \
    --if-exists \
    /app/backups/daily/ofs_backup_20260513_030000.dump

# 3. Verificar restauração
PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "SELECT count(*) FROM ofcs; SELECT count(*) FROM usuarios;"
```

#### 6.2.3 Endpoint de Restauração

```python
@router.post("/admin/backup/{backup_id}/restore")
@audit(action="BACKUP_RESTORE", resource="BACKUP", severity="CRITICAL")
async def restore_backup(
    backup_id: UUID,
    confirm_password: str = Body(..., embed=True),
    current_user: User = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    # Dupla verificação: senha do admin
    if not verify_password(confirm_password, current_user.password_hash):
        raise HTTPException(status_code=403, detail="Senha incorreta.")

    backup = await db.get(Backup, backup_id)
    if not backup:
        raise HTTPException(status_code=404, detail="Backup não encontrado.")

    # Ativar modo manutenção
    set_maintenance_mode(True)

    try:
        # Executar pg_restore
        result = subprocess.run([
            "pg_restore",
            "-h", settings.DB_HOST,
            "-U", settings.DB_USER,
            "-d", settings.DB_NAME,
            "--clean",
            "--if-exists",
            backup.filepath,
        ], capture_output=True, text=True, timeout=300)

        if result.returncode != 0:
            raise Exception(f"pg_restore falhou: {result.stderr}")

        backup.status = "restaurado"
        await db.commit()

    except Exception as e:
        logger.critical(f"Falha na restauração do backup {backup_id}: {e}")
        raise HTTPException(status_code=500, detail="Falha na restauração.")

    finally:
        set_maintenance_mode(False)

    return {"message": "Backup restaurado com sucesso."}
```

### 6.3 Backup de PDFs e Arquivos

- Diretório `/app/reports/` (PDFs gerados) mapeado como volume Docker
- Incluso no backup do diretório `backups/files/` com rsync:

```bash
# No script de backup
rsync -av /app/reports/ "$BACKUP_DIR/files/reports/"
```

- PDFs são regeneráveis (podem ser gerados novamente se perdidos) — prioridade é o banco de dados

### 6.4 Disaster Recovery

#### Plano de Recuperação de Desastre (DRP)

**Cenário:** Falha total do servidor. Necessidade de reconstruir ambiente do zero.

| Passo | Ação | Tempo Estimado |
|-------|------|---------------|
| 1 | Provisionar novo servidor com Docker e Docker Compose | 30 min |
| 2 | Copiar `docker-compose.yml` e `.env` do repositório seguro | 5 min |
| 3 | Copiar último backup do NAS/pasta de rede | 10 min |
| 4 | Executar `docker compose up -d db` | 2 min |
| 5 | Restaurar banco: `pg_restore` | 10 min |
| 6 | Executar `docker compose up -d` (todos os serviços) | 5 min |
| 7 | Verificar integridade: login, consultas, relatórios | 15 min |

| Métrica | Objetivo |
|---------|----------|
| **RTO** (Recovery Time Objective) | < 2 horas |
| **RPO** (Recovery Point Objective) | < 24 horas (perda máxima de 1 dia) |

**Checklist de itens a manter fora do servidor (repositório seguro / NAS):**
- [ ] `docker-compose.yml`
- [ ] `.env` (com secrets)
- [ ] Scripts de backup e restore
- [ ] Último backup full (diário)
- [ ] Imagens Docker base (ou Dockerfiles)

---

## 7. Recomendações de Hardening

### 7.1 Container Security

#### Dockerfiles com usuário non-root

```dockerfile
# backend/Dockerfile
FROM python:3.12-slim

# Criar usuário não-privilegiado
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Mudar owner para appuser
RUN chown -R appuser:appuser /app

USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```dockerfile
# frontend/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
# nginx já roda como non-root na alpine
```

#### Docker Security Configuration

```yaml
# docker-compose.yml
services:
  backend:
    build: ./backend
    user: "1000:1000"               # UID/GID do appuser
    read_only: true                  # sistema de arquivos somente leitura
    tmpfs:
      - /tmp                         # apenas /tmp gravável
    security_opt:
      - no-new-privileges:true      # impede escalação de privilégios
    cap_drop:
      - ALL                          # remove todas as capabilities
    cap_add:
      - NET_BIND_SERVICE             # apenas bind em porta
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - DB_PASSWORD=${DB_PASSWORD}
    secrets:
      - jwt_secret
      - db_password

  db:
    image: postgres:16-alpine
    user: "999:999"                  # postgres user
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_DB: ${DB_NAME}

secrets:
  jwt_secret:
    file: ./secrets/jwt_secret.txt
  db_password:
    file: ./secrets/db_password.txt

volumes:
  pgdata:
  backups:
  reports:
```

### 7.2 PostgreSQL Security

#### pg_hba.conf (Host-Based Authentication)

```
# Permitir apenas conexões locais e da rede Docker interna
local   all             all                     scram-sha-256
host    all             all     172.16.0.0/12   scram-sha-256
host    all             all     127.0.0.1/32    scram-sha-256
# Rejeitar todo o resto
host    all             all     all             reject
```

#### Usuário de Aplicação com Privilégios Mínimos

```sql
-- Usuário da aplicação NÃO é superuser
CREATE ROLE ofs_app WITH LOGIN PASSWORD '******';
GRANT CONNECT ON DATABASE ofs_feedback TO ofs_app;
GRANT USAGE ON SCHEMA public TO ofs_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ofs_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO ofs_app;

-- Permissões para futuras tabelas
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ofs_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO ofs_app;

-- NÃO conceder: CREATE, DROP, TRUNCATE, superuser
```

#### Configurações de Segurança

```ini
# postgresql.conf — hardening
ssl = off                              # off em MVP; on quando HTTPS disponível
password_encryption = scram-sha-256
log_connections = on
log_disconnections = on
log_duration = off                     # não logar queries (performance + privacidade)
log_statement = 'mod'                  # logar apenas DDL/DML (ALTER, INSERT, UPDATE, DELETE)
log_min_duration_statement = 1000      # logar queries > 1s (análise de performance)
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

### 7.3 Network Security

#### Topologia de Rede

```
┌───────────────────────────────────────────┐
│  SERVIDOR (host)                          │
│  ┌─────────────────────────────────────┐  │
│  │  Docker Network: ofs_net (internal) │  │
│  │  ┌──────────┐  ┌──────────┐  ┌────┐ │  │
│  │  │  nginx   │  │ backend  │  │ db │ │  │
│  │  │  :80/443 │→│  :8000   │→│:5432│ │  │
│  │  └────┬─────┘  └──────────┘  └────┘ │  │
│  └───────┼──────────────────────────────┘  │
│          │                                 │
│   Firewall: apenas 80, 443, 22 (admin)    │
└──────────┼─────────────────────────────────┘
           │
    Rede Corporativa
```

#### Docker Compose Network Configuration

```yaml
networks:
  ofs_net:
    driver: bridge
    internal: false         # false para permitir acesso externo via nginx
    ipam:
      config:
        - subnet: 172.28.0.0/16

services:
  nginx:
    ports:
      - "80:80"
      # - "443:443"   # quando HTTPS habilitado
    networks:
      - ofs_net

  backend:
    expose:
      - "8000"             # exposto apenas na rede Docker (não no host)
    networks:
      - ofs_net

  db:
    expose:
      - "5432"             # exposto apenas na rede Docker
    networks:
      - ofs_net
```

#### Firewall do Servidor (iptables / Windows Firewall)

```bash
# Apenas portas essenciais expostas no host
# 22  - SSH (admin)
# 80  - HTTP (aplicação)
# 443 - HTTPS (quando configurado)

iptables -A INPUT -p tcp --dport 22  -j ACCEPT
iptables -A INPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P INPUT DROP
```

### 7.4 Environment Variables e Secrets

**Estrutura do `.env` (NUNCA commitar):**

```bash
# .env — NÃO COMMITAR (adicionar ao .gitignore)
JWT_SECRET=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0
DB_USER=ofs_app
DB_PASSWORD=senha_segura_db
DB_NAME=ofs_feedback
DB_HOST=db
DB_PORT=5432
ADMIN_DEFAULT_PASSWORD=SenhaTemp123
```

**Template `.env.example` (commitar):**

```bash
# .env.example — Template de configuração (pode commitar)
JWT_SECRET=<gerar com: openssl rand -hex 32>
DB_USER=ofs_app
DB_PASSWORD=<senha_segura>
DB_NAME=ofs_feedback
DB_HOST=db
DB_PORT=5432
ADMIN_DEFAULT_PASSWORD=<senha_temporaria_admin>
```

**.gitignore:**

```
.env
secrets/
*.dump
backups/
```

### 7.5 Log Sanitization

```python
# backend/app/core/logging_config.py
import logging
import re

class SanitizingFormatter(logging.Formatter):
    """Remove dados sensíveis dos logs."""

    SENSITIVE_PATTERNS = [
        (r'(password["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
        (r'(token["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
        (r'(secret["\']?\s*[:=]\s*["\']?)([^"\'&\s]+)', r'\1[REDACTED]'),
        (r'(Bearer\s+)([^\s]+)', r'\1[REDACTED]'),
    ]

    def format(self, record):
        msg = super().format(record)
        for pattern, replacement in self.SENSITIVE_PATTERNS:
            msg = re.sub(pattern, replacement, msg, flags=re.IGNORECASE)
        return msg
```

---

## 8. Conformidade (Opcional Futuro)

### 8.1 Preparação para LGPD

| Requisito LGPD | Status Atual | Ação Futura |
|---------------|-------------|-------------|
| **Finalidade:** Dados coletados apenas para feedback comportamental | ✅ Atende | Documentar formalmente |
| **Consentimento:** Usuários são funcionários — consentimento via contrato de trabalho | ⚠️ Parcial | Adicionar termo de uso no primeiro login |
| **Acesso aos dados:** Usuário pode ver seus próprios OFCs | ✅ Atende | Implementar endpoint `GET /me/data` para exportação |
| **Correção de dados:** OFCs editáveis (dentro da janela) | ✅ Atende | — |
| **Exclusão de dados:** Soft delete implementado | ✅ Atende | Implementar exclusão permanente após X anos |
| **Portabilidade:** Exportação CSV por usuário | ✅ Atende | Formato JSON estruturado para interoperabilidade |
| **Registro de operações:** Audit log completo | ✅ Atende | — |
| **Encarregado (DPO):** Não designado | ❌ Pendente | Nomear DPO da Security Dynamics |

### 8.2 Preparação para ISO 27001

| Domínio ISO 27001 | Evidência no Sistema |
|-------------------|---------------------|
| A.5 — Políticas de segurança | Este documento |
| A.6 — Organização da segurança | Perfis e responsabilidades definidos |
| A.7 — Segurança em RH | Perfis RBAC, treinamento necessário |
| A.8 — Gestão de ativos | Empresas, contratos, usuários catalogados |
| A.9 — Controle de acesso | RBAC + JWT + data scoping |
| A.10 — Criptografia | bcrypt + JWT HS256 + HTTPS planejado |
| A.11 — Segurança física | Servidor em sala segura (responsabilidade do cliente) |
| A.12 — Operações | Backup automático, restore documentado |
| A.13 — Comunicações | Rede Docker isolada, firewall |
| A.14 — Desenvolvimento | FastAPI com validação, SQLAlchemy parametrizado |
| A.16 — Gestão de incidentes | Audit log, logging, monitoramento |
| A.17 — Continuidade | Disaster recovery documentado (RTO < 2h, RPO < 24h) |
| A.18 — Conformidade | Preparação LGPD, logs para auditoria externa |

### 8.3 Preparação para Auditoria Externa

**Pacote de evidências exportável (Admin):**

```python
@router.get("/admin/audit/export-package")
async def export_audit_package(
    date_from: date,
    date_to: date,
    current_user: User = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db)
):
    """
    Gera pacote ZIP com:
    - audit_logs.csv (todos os logs do período)
    - users.csv (lista de usuários ativos no período)
    - ofcs_summary.csv (resumo de OFCs do período)
    - access_control.json (matriz de permissões atual)
    """
    # ... gerar ZIP e retornar
```

---

## Apêndice A: Resumo de Tabelas de Segurança

```sql
-- Histórico de senhas (evitar reuso)
CREATE TABLE password_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    password_hash   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Refresh tokens (gerenciamento de sessão)
CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash      TEXT NOT NULL UNIQUE,      -- hash do refresh token
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked         BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tentativas de login (bloqueio)
CREATE TABLE login_attempts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(100) NOT NULL,
    success         BOOLEAN NOT NULL,
    ip_address      INET,
    user_agent      TEXT,
    failure_reason  VARCHAR(100),              -- 'invalid_password', 'user_not_found', 'account_locked'
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tokens revogados (blacklist JWT)
CREATE TABLE revoked_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    jti             VARCHAR(255) NOT NULL UNIQUE,  -- JWT ID
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Apêndice B: Cronograma de Implementação Recomendado

| Fase | Itens | Prazo |
|------|-------|-------|
| **Fase 1 — MVP Seguro** | RBAC completo, bcrypt, JWT, audit log básico, soft delete, rate limiting | Imediato |
| **Fase 2 — Hardening** | Security headers, senha com expiração, bloqueio por tentativas, backup automático, optimistic locking | 2-4 semanas |
| **Fase 3 — Produção** | HTTPS (CA interna), secrets management, container non-root, firewall, disaster recovery testado | 4-8 semanas |
| **Fase 4 — Conformidade** | LGPD consentimento, exportação auditoria, ISO 27001 documentação complementar | 3-6 meses |

---

**Elaborado por:** Especialista em Segurança da Informação  
**Aprovado por:** Security Dynamics — Diretoria de TI  
**Próxima revisão:** Novembro 2026
