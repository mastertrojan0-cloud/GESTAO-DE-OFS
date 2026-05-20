# ESPECIFICAÇÃO DE AUTENTICAÇÃO, ACESSO E RASTREABILIDADE

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Arquitetura da Autenticação](#1-arquitetura-da-autenticação)
2. [Fluxo Completo de Login](#2-fluxo-completo-de-login)
3. [Fluxo de Sessão](#3-fluxo-de-sessão)
4. [Política de Senha](#4-política-de-senha)
5. [Estratégia de Autorização (RBAC)](#5-estratégia-de-autorização-rbac)
6. [Estratégia de Auditoria](#6-estratégia-de-auditoria)
7. [Estrutura das Tabelas](#7-estrutura-das-tabelas)
8. [Middleware de Autenticação e Autorização](#8-middleware-de-autenticação-e-autorização)
9. [Regras por Perfil](#9-regras-por-perfil)
10. [Estratégia Frontend](#10-estratégia-frontend)
11. [Estratégia Backend](#11-estratégia-backend)
12. [Estratégia PostgreSQL](#12-estratégia-postgresql)
13. [Estratégia Docker](#13-estratégia-docker)
14. [Estratégia de Rastreabilidade](#14-estratégia-de-rastreabilidade)
15. [Estratégia de Cancelamento Lógico](#15-estratégia-de-cancelamento-lógico)
16. [Estratégia de Logs](#16-estratégia-de-logs)
17. [Estratégia de Segurança Operacional](#17-estratégia-de-segurança-operacional)
18. [Recomendações Finais](#18-recomendações-finais)

---

## 1. Arquitetura da Autenticação

### 1.1 Visão Geral

```
┌──────────────────────────────────────────────────────────────────────┐
│                        ARQUITETURA DE AUTH                            │
│                                                                       │
│  ┌──────────┐     ┌─────────────────┐     ┌──────────────────────┐  │
│  │ Browser  │────▶│ FastAPI Backend  │────▶│ PostgreSQL            │  │
│  │ (React)  │     │                  │     │                      │  │
│  │          │     │ POST /auth/login │     │ users (bcrypt hash)  │  │
│  │          │     │ POST /auth/refresh│    │ revoked_tokens       │  │
│  │          │     │ POST /auth/logout│     │ password_history     │  │
│  │          │     │                  │     │ audit_logs           │  │
│  └──────────┘     └─────────────────┘     └──────────────────────┘  │
│                                                                       │
│  TOKENS:                                                              │
│  ┌─────────────────┬─────────────────────────────────────────────┐   │
│  │ ACCESS TOKEN    │ JWT HS256, 15 minutos                        │   │
│  │                 │ Payload: sub, perfil, type, jti, exp, iat   │   │
│  │                 │ Armazenado: memória JS (não persiste)        │   │
│  ├─────────────────┼─────────────────────────────────────────────┤   │
│  │ REFRESH TOKEN   │ JWT HS256, 7 dias                            │   │
│  │                 │ Payload: sub, type, jti, exp, iat            │   │
│  │                 │ Armazenado: localStorage (intranet, sem CDN) │   │
│  └─────────────────┴─────────────────────────────────────────────┘   │
│                                                                       │
│  SEGURANÇA:                                                           │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ • bcrypt cost 12                                              │    │
│  │ • Lockout: 5 falhas → 30 minutos                              │    │
│  │ • Senha mínima: 12 caracteres, complexidade                   │    │
│  │ • Histórico: últimas 6 senhas bloqueadas                      │    │
│  │ • Expiração: 90 dias                                          │    │
│  │ • Token blacklist (revoked_tokens)                            │    │
│  │ • Refresh token rotation (revoga anterior ao renovar)         │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 Stack de Autenticação

| Componente | Tecnologia | Configuração |
|-----------|-----------|-------------|
| Algoritmo JWT | HS256 | Chave simétrica >= 256 bits |
| Hash senha | bcrypt | Cost factor 12 |
| Access Token TTL | 15 minutos | 900 segundos |
| Refresh Token TTL | 7 dias | 604800 segundos |
| Lockout | 5 falhas | 30 minutos bloqueio |
| Senha min | 12 caracteres | 1 maiúscula + 1 minúscula + 1 dígito + 1 especial |
| Histórico senha | 6 últimas | Bloqueia reuso |
| Expiração senha | 90 dias | Aviso em tela, reset via admin |

---

## 2. Fluxo Completo de Login

### 2.1 Sequência Backend

```
POST /api/auth/login
Body: { "username": "joao.silva", "password": "Senha@123" }

PASSO 1: Validar payload (Pydantic)
PASSO 2: SELECT * FROM users WHERE username = :username
PASSO 3: Se usuário não existe → 401 "Credenciais inválidas"
PASSO 4: Se is_active = FALSE → 403 "Usuário inativo"
PASSO 5: Se locked_until > NOW() → 423 "Bloqueado até {timestamp}"
PASSO 6: bcrypt.verify(password, password_hash)
         ├── FALSE → login_attempts++
         │           Se >= 5 → locked_until = NOW() + 30min → 423
         │           Senão → 401 "Credenciais inválidas"
         └── TRUE → login_attempts = 0, last_login = NOW()
PASSO 7: Gerar access_token + refresh_token
PASSO 8: Response 200 com tokens + user data
```

### 2.2 Código Python — Login Endpoint

```python
# api/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone, timedelta

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/login")
async def login(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    # Buscar usuário
    result = await db.execute(
        select(User).where(User.username == body.username)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=401, detail="Credenciais inválidas")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Usuário inativo. Contate o administrador.")
    
    if user.locked_until and user.locked_until > datetime.now(timezone.utc):
        bloqueio = user.locked_until.strftime("%d/%m/%Y %H:%M")
        raise HTTPException(status_code=423, detail=f"Usuário bloqueado até {bloqueio}")
    
    if not verify_password(body.password, user.password_hash):
        user.login_attempts += 1
        if user.login_attempts >= 5:
            user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=30)
            user.login_attempts = 0
        await db.commit()
        raise HTTPException(status_code=401, detail="Credenciais inválidas")
    
    # Login OK
    user.login_attempts = 0
    user.last_login = datetime.now(timezone.utc)
    await db.commit()
    
    access_token = create_access_token(str(user.id), user.role)
    refresh_token = create_refresh_token(str(user.id))
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": 900,
        "user": {
            "id": str(user.id),
            "username": user.username,
            "full_name": user.full_name,
            "role": user.role,
            "company_id": user.company_id,
        }
    }
```

### 2.3 Fluxo de Logout

```
POST /api/auth/logout
Body: { "refresh_token": "eyJ..." }

1. Decodificar refresh_token (verify_exp=False para pegar jti)
2. INSERT INTO revoked_tokens (jti, user_id, expires_at)
3. Também revogar access_token associado (se enviado)
4. Response: { "success": true }
```

### 2.4 Fluxo de Refresh

```
POST /api/auth/refresh
Body: { "refresh_token": "eyJ..." }

1. Decodificar refresh_token (verify_exp=True)
2. Verificar type == "refresh"
3. Verificar se jti NÃO está em revoked_tokens
4. Verificar se usuário ainda existe e is_active
5. REVOGAR refresh_token atual (INSERT revoked_tokens)
6. GERAR novo par access_token + refresh_token
7. Response com novos tokens
```

---

## 3. Fluxo de Sessão

### 3.1 Estados da Sessão

```
┌────────────┐     ┌──────────────┐     ┌──────────────┐
│  ATIVA     │────▶│  EXPIRADA    │────▶│   LOGOUT     │
│ (access OK)│     │ (access exp) │     │ (refresh rev)│
└────────────┘     └──────┬───────┘     └──────────────┘
                          │
                          │ POST /auth/refresh
                          ▼
                   ┌──────────────┐
                   │   RENOVADA   │
                   │ (novo access)│
                   └──────────────┘
```

### 3.2 Renovação Automática (Frontend)

```typescript
// Axios interceptor — api.ts
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      const store = useAuthStore.getState();
      const newAccessToken = await store.refreshSession();
      
      if (newAccessToken) {
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        return api(originalRequest);
      }
      
      // Refresh falhou → logout
      store.logout({ expired: true });
      window.location.href = '/login?expired=1';
    }
    
    return Promise.reject(error);
  }
);
```

### 3.3 Sessão Expirada (Frontend)

- Detecta `isAuthenticated` → false na store
- Exibe modal: "Sessão expirada. Redirecionando em 5s..."
- Botão "Ir para o Login"
- Cross-tab: evento `storage` detecta logout em outra aba

---

## 4. Política de Senha

### 4.1 Regras

| Regra | Valor |
|-------|-------|
| Tamanho mínimo | 12 caracteres |
| Maiúscula | ≥ 1 |
| Minúscula | ≥ 1 |
| Dígito | ≥ 1 |
| Caractere especial | ≥ 1 (`!@#$%^&*()_+-=[]{}|;:',.<>?/~`) |
| Hash | bcrypt, cost factor 12 |
| Expiração | 90 dias |
| Histórico | Últimas 6 senhas bloqueadas |
| Bloqueio | 5 tentativas → 30 minutos |

### 4.2 Código Python — Validação e Hash

```python
import bcrypt
import re

BCRYPT_ROUNDS = 12

def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(rounds=BCRYPT_ROUNDS)).decode("utf-8")

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))

def validate_password_strength(password: str) -> tuple[bool, str | None]:
    if len(password) < 12:
        return False, "Mínimo 12 caracteres"
    if not re.search(r"[A-Z]", password):
        return False, "Pelo menos 1 letra maiúscula"
    if not re.search(r"[a-z]", password):
        return False, "Pelo menos 1 letra minúscula"
    if not re.search(r"\d", password):
        return False, "Pelo menos 1 dígito"
    if not re.search(r"[!@#$%^&*()_+\-=\[\]{}|;:',.<>?/~`]", password):
        return False, "Pelo menos 1 caractere especial"
    return True, None

async def is_password_reused(user_id: str, new_password: str, db) -> bool:
    """Verifica se a senha está no histórico das últimas 6."""
    result = await db.execute(
        select(PasswordHistory.password_hash)
        .where(PasswordHistory.user_id == user_id)
        .order_by(PasswordHistory.changed_at.desc())
        .limit(6)
    )
    for row in result.scalars().all():
        if verify_password(new_password, row):
            return True
    return False
```

---

## 5. Estratégia de Autorização (RBAC)

### 5.1 Matriz Completa

| Ação | Observador | Supervisor | Gestor | Admin |
|------|:---:|:---:|:---:|:---:|
| **OFS/OFS** ||||
| Criar OFS | ✅ | ✅ | ✅ | ✅ |
| Ver OFCs | Apenas seus | Sua empresa | Todos | Todos |
| Editar OFS | Seu, 24h | Empresa, 48h | Ilimitado | Ilimitado |
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Restaurar OFS | ❌ | ❌ | ❌ | ✅ |
| **Métricas** ||||
| Ver métricas | ❌ | Sua empresa | Todas | Todas |
| **Relatórios PDF** ||||
| PDF individual | Seus | Empresa | Todos | Todos |
| PDF semanal | ❌ | ❌ | ✅ | ✅ |
| **Administração** ||||
| Gerenciar usuários | ❌ | ❌ | Sua empresa | Todos |
| Gerenciar empresas | ❌ | ❌ | ❌ | ✅ |
| Gerenciar contratos | ❌ | ❌ | Sua empresa | Todos |
| Gerenciar metas | ❌ | ❌ | Sua empresa | Todos |
| Ver auditoria | ❌ | ❌ | ❌ | ✅ |
| Backup/Restore | ❌ | ❌ | ❌ | ✅ |

### 5.2 Dependências FastAPI (Código)

```python
# api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt

security = HTTPBearer(auto_error=False)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not credentials:
        raise HTTPException(status_code=401, detail="Token de acesso ausente")
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401)
        # Verificar blacklist
        jti = payload.get("jti")
        if jti:
            revoked = await db.get(RevokedToken, jti)
            if revoked:
                raise HTTPException(status_code=401, detail="Token revogado")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido ou expirado")
    
    user = await db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=403, detail="Usuário inativo")
    return user

def require_role(*roles: str):
    """Factory: Dependency que exige um ou mais perfis."""
    async def checker(current_user: User = Depends(get_current_user)):
        if current_user.role not in roles:
            raise HTTPException(status_code=403, detail=f"Requer perfil: {', '.join(roles)}")
        return current_user
    return checker

async def get_data_scope(current_user: User = Depends(get_current_user)) -> dict:
    """Retorna filtros de visibilidade por perfil."""
    if current_user.role == "observador":
        return {"generated_by": current_user.id}
    elif current_user.role == "supervisor":
        return {"company_id": current_user.company_id}
    return {}  # gestor, admin: sem filtro
```

### 5.3 Regras de Edição (Código)

```python
EDIT_WINDOWS = {
    "observador": timedelta(hours=24),
    "supervisor": timedelta(hours=48),
}

async def can_edit_ofc(OFS: OfcRecord, user: User) -> bool:
    if user.role in ("gestor", "admin"):
        return True
    if OFS.status == "cancelado":
        return False
    if user.role == "observador" and OFS.generated_by != user.id:
        return False
    if user.role == "supervisor" and OFS.company_id != user.company_id:
        return False
    window = EDIT_WINDOWS.get(user.role)
    if window and (datetime.now(timezone.utc) - OFS.created_at) > window:
        return False
    return True
```

---

## 6. Estratégia de Auditoria

### 6.1 Eventos Auditáveis (15 Essenciais)

| # | Evento | Severidade | Dados |
|---|--------|:---:|-------|
| 1 | LOGIN_SUCCESS | INFO | user_id, username, perfil, ip |
| 2 | LOGIN_FAILED | WARN | username, ip, motivo |
| 3 | LOGOUT | INFO | user_id, username |
| 4 | PASSWORD_CHANGE | WARN | user_id |
| 5 | OFC_CREATE | INFO | user_id, ofc_id, tipo, empresa |
| 6 | OFC_EDIT | WARN | user_id, ofc_id, campos_alterados |
| 7 | OFC_CANCEL | WARN | user_id, ofc_id, motivo |
| 8 | REPORT_GENERATE | INFO | user_id, tipo, parametros |
| 9 | USER_CREATE | WARN | admin_id, new_user_id, perfil |
| 10 | USER_UPDATE | WARN | admin_id, user_id, campos |
| 11 | USER_DISABLE | WARN | admin_id, user_id |
| 12 | TARGET_UPDATE | WARN | user_id, target_id |
| 13 | BACKUP_MANUAL | INFO | user_id, filename |
| 14 | BACKUP_RESTORE | CRITICAL | user_id, backup_id |
| 15 | PERMISSION_DENIED | WARN | user_id, recurso, ip |

### 6.2 Middleware de Auditoria (Código)

```python
# middleware/audit.py
from starlette.background import BackgroundTask

class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        
        # Captura automática de 401/403
        if response.status_code in (401, 403):
            bg = BackgroundTask(write_audit_log, {
                "action": "PERMISSION_DENIED" if response.status_code == 403 else "LOGIN_FAILED",
                "resource": request.url.path,
                "severity": "WARN",
                "ip_address": request.client.host if request.client else None,
            })
            response.background = bg
        
        return response

def audit_action(action: str, resource: str, severity: str = "INFO"):
    """Decorator para endpoints."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            result = await func(*args, **kwargs)
            # Registra em background (não bloqueia resposta)
            write_audit_log({
                "action": action,
                "resource": resource,
                "severity": severity,
                # ... dados do request
            })
            return result
        return wrapper
    return decorator
```

### 6.3 Consulta de Auditoria

```
GET /api/audit?user_id=&action=&resource=&start_date=&end_date=&page=&page_size=

Response:
{
  "data": [
    {
      "id": 123,
      "timestamp": "2026-05-13T14:30:00Z",
      "user_id": "uuid",
      "username": "joao.silva",
      "action": "OFC_CREATE",
      "resource": "ofc_records",
      "resource_id": "uuid",
      "details": {"tipo": "Positivo/Seguro", "empresa": "Security Dynamics"},
      "ip_address": "192.168.1.50",
      "severity": "INFO"
    }
  ],
  "pagination": { "page": 1, "page_size": 50, "total": 1234, "pages": 25 }
}
```

---

## 7. Estrutura das Tabelas

### 7.1 users

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(100) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(200) NOT NULL,
    email           VARCHAR(200),
    role            VARCHAR(20) NOT NULL CHECK (role IN ('observador','supervisor','gestor','admin')),
    company_id      INT REFERENCES companies(id),
    is_active       BOOLEAN DEFAULT TRUE,
    login_attempts  INT DEFAULT 0,
    locked_until    TIMESTAMPTZ,
    last_login      TIMESTAMPTZ,
    password_expires_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_company ON users(company_id);
```

### 7.2 revoked_tokens

```sql
CREATE TABLE revoked_tokens (
    jti         VARCHAR(255) PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_revoked_user ON revoked_tokens(user_id);
CREATE INDEX idx_revoked_expires ON revoked_tokens(expires_at);
```

### 7.3 password_history

```sql
CREATE TABLE password_history (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    changed_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_pass_hist_user ON password_history(user_id, changed_at DESC);
```

### 7.4 audit_logs

```sql
CREATE TABLE audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    timestamp   TIMESTAMPTZ DEFAULT NOW(),
    user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    username    VARCHAR(100),
    action      VARCHAR(50) NOT NULL,
    resource    VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    details     JSONB DEFAULT '{}',
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    severity    VARCHAR(20) DEFAULT 'INFO',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_audit_ts ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id, timestamp DESC);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_resource ON audit_logs(resource, resource_id);
CREATE INDEX idx_audit_severity ON audit_logs(severity);
CREATE INDEX idx_audit_details ON audit_logs USING GIN(details);
```

### 7.5 ofc_edit_log

```sql
CREATE TABLE ofc_edit_log (
    id              BIGSERIAL PRIMARY KEY,
    ofc_record_id   UUID NOT NULL,  -- sem FK para sobreviver a deleção do OFS
    edited_by       UUID NOT NULL REFERENCES users(id),
    field_changed   VARCHAR(100) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_edit_ofc ON ofc_edit_log(ofc_record_id, edited_at DESC);
```

---

## 8. Middleware de Autenticação e Autorização

### 8.1 JWT — Criação e Validação

```python
# core/security.py
from jose import jwt
from datetime import datetime, timezone, timedelta
import uuid

SECRET_KEY = os.getenv("JWT_SECRET", "chave-min-32-caracteres-aleatorios-aqui")
ALGORITHM = "HS256"
ACCESS_EXPIRE = 900       # 15 minutos
REFRESH_EXPIRE = 604800   # 7 dias

def create_access_token(user_id: str, role: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({
        "sub": user_id,
        "role": role,
        "type": "access",
        "jti": str(uuid.uuid4()),
        "iat": now,
        "exp": now + timedelta(seconds=ACCESS_EXPIRE),
    }, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({
        "sub": user_id,
        "type": "refresh",
        "jti": str(uuid.uuid4()),
        "iat": now,
        "exp": now + timedelta(seconds=REFRESH_EXPIRE),
    }, SECRET_KEY, algorithm=ALGORITHM)
```

### 8.2 Rotas Públicas vs Protegidas

```python
# main.py
PUBLIC_PATHS = {
    "/api/auth/login",
    "/api/auth/refresh",
    "/api/health",
    "/docs",
    "/openapi.json",
}

# Middleware de auth aplicado em todas as rotas exceto PUBLIC_PATHS
```

---

## 9. Regras por Perfil

### 9.1 Observador

- Cria OFS/OFS
- Vê APENAS seus registros (WHERE generated_by = user.id)
- Edita seus registros em até 24h
- Gera PDF individual dos seus registros
- **Não vê**: Métricas, Relatórios, Admin, registros de outros

### 9.2 Supervisor

- Tudo do Observador
- Vê registros da sua empresa (WHERE company_id = user.company_id)
- Edita registros da empresa em até 48h
- Vê Métricas da Semana (filtrado por empresa)
- Gera Relatórios do contrato
- **Não pode**: Cancelar OFS, ver auditoria, gerenciar usuários de outra empresa

### 9.3 Gestor

- Vê TODOS os registros
- Edita sem limite de tempo
- Pode CANCELAR OFCs
- Vê Métricas de todas as empresas
- Gerencia Metas
- Gerencia usuários da sua empresa
- **Não pode**: Gerenciar empresas, ver auditoria, backup/restore

### 9.4 Admin

- Acesso TOTAL
- CRUD de usuários, empresas, contratos
- Cancelar e RESTAURAR OFCs
- Ver auditoria
- Backup manual e restore
- Configurar metas

---

## 10. Estratégia Frontend

### 10.1 Tela de Login — Estados

| Estado | Visual |
|--------|--------|
| Digitando | Campos limpos, botão "Entrar" habilitado |
| Enviando | Botão com spinner "Entrando...", campos desabilitados |
| Erro credenciais | Banner vermelho: "Usuário ou senha inválidos" |
| Erro bloqueado | Banner âmbar: "Usuário bloqueado até DD/MM HH:mm" |
| Erro inativo | Banner vermelho: "Usuário inativo. Contate o administrador." |
| Sucesso | Banner verde, redireciona em 800ms |

### 10.2 Zustand Auth Store

```typescript
// stores/authStore.ts
interface AuthState {
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  
  login: (username: string, password: string) => Promise<void>;
  logout: (options?: { expired?: boolean }) => void;
  refreshSession: () => Promise<string | null>;
  hasRole: (...roles: string[]) => boolean;
}
```

### 10.3 Protected Route

```typescript
// components/ProtectedRoute.tsx
function ProtectedRoute({ children, roles }: { children: ReactNode; roles?: string[] }) {
  const { isAuthenticated, user } = useAuthStore();
  const location = useLocation();
  
  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  
  if (roles && user && !roles.includes(user.role)) {
    return <Navigate to="/" replace />;
  }
  
  return <>{children}</>;
}
```

### 10.4 Sidebar Condicional

```typescript
const sidebarLinks = [
  { to: "/", label: "Início", icon: Home, roles: ALL },
  { to: "/OFS/novo", label: "Nova OFS", icon: Plus, roles: ALL },
  { to: "/OFS", label: "Registros", icon: List, roles: ALL },
  { to: "/consulta", label: "Consulta", icon: Search, roles: ALL },
  { to: "/metricas", label: "Métricas", icon: BarChart3, roles: ["supervisor","gestor","admin"] },
  { to: "/relatorios", label: "Relatórios", icon: FileText, roles: ["gestor","admin"] },
];

// Seção Admin visível apenas para admin
{user?.role === "admin" && (
  <>
    <SidebarLink to="/admin/usuarios" label="Usuários" icon={Users} />
    <SidebarLink to="/admin/empresas" label="Empresas" icon={Building2} />
    <SidebarLink to="/admin/metas" label="Metas" icon={Target} />
    <SidebarLink to="/admin/auditoria" label="Auditoria" icon={ShieldCheck} />
  </>
)}
```

---

## 11. Estratégia Backend

### 11.1 Estrutura de Arquivos (Auth)

```
backend/app/
├── api/
│   ├── deps.py          # get_current_user, require_role, get_data_scope
│   └── auth.py          # POST login, refresh, logout, GET me, PUT change-password
├── core/
│   └── security.py      # create_access_token, create_refresh_token, hash/verify password
├── models/
│   ├── user.py          # User model
│   ├── revoked_token.py # RevokedToken model
│   └── password_history.py
└── middleware/
    └── audit.py         # AuditMiddleware + @audit_action decorator
```

### 11.2 Validação: Zero Upload/Mídia

**Confirmado via grep no código:**
- 0 ocorrências de `UploadFile`, `Form(`, `multipart`, `form-data`, `File(`
- Todos os payloads são `application/json`
- Nenhum endpoint aceita arquivos binários
- Campo mais longo: `comportamento_observado` (TEXT, puramente string)

---

## 12. Estratégia PostgreSQL

### 12.1 Roles e Permissões

```sql
-- Role da aplicação (mínimo privilégio)
CREATE ROLE ofs_app WITH LOGIN PASSWORD 'senha_segura';
GRANT CONNECT ON DATABASE ofs_db TO ofs_app;
GRANT USAGE ON SCHEMA public TO ofs_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO ofs_app;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO ofs_app;

-- audit_logs: apenas INSERT e SELECT (imutável)
REVOKE UPDATE, DELETE ON audit_logs FROM ofs_app;

-- ofc_edit_log: apenas INSERT e SELECT
REVOKE UPDATE, DELETE ON ofc_edit_log FROM ofs_app;
```

### 12.2 Configurações de Segurança (postgresql.conf)

```ini
password_encryption = 'scram-sha-256'
log_connections = on
log_disconnections = on
log_statement = 'mod'          # Registra INSERT/UPDATE/DELETE
log_min_duration_statement = 500  # Log queries > 500ms
```

### 12.3 Limpeza de Tokens Expirados

```sql
-- Função agendada via pg_cron ou APScheduler
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS void AS $$
BEGIN
    DELETE FROM revoked_tokens WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Executar diariamente às 04:00
-- SELECT cron.schedule('cleanup-tokens', '0 4 * * *', 'SELECT cleanup_expired_tokens()');
```

---

## 13. Estratégia Docker

### 13.1 Configurações de Segurança

```yaml
services:
  backend:
    user: "1000:1000"           # non-root
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    environment:
      - JWT_SECRET=${JWT_SECRET}  # Via .env, nunca hardcoded
      - DB_PASSWORD=${DB_PASSWORD}
  
  db:
    user: "70:70"               # postgres user
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
```

### 13.2 Variáveis de Ambiente (.env)

```bash
# JWT
JWT_SECRET=openssl-rand-hex-32-chave-aqui
JWT_ALGORITHM=HS256
JWT_ACCESS_EXPIRE_MINUTES=15
JWT_REFRESH_EXPIRE_DAYS=7

# Banco
DB_HOST=db
DB_PORT=5432
DB_NAME=ofs_db
DB_USER=ofs_app
DB_PASSWORD=senha-forte-gerada

# Senhas
PASSWORD_MIN_LENGTH=12
PASSWORD_EXPIRE_DAYS=90
MAX_LOGIN_ATTEMPTS=5
LOCKOUT_MINUTES=30
```

---

## 14. Estratégia de Rastreabilidade

### 14.1 O Que é Rastreado em Cada OFS

```
┌─────────────────────────────────────────────────────────────┐
│                    RASTREABILIDADE DO OFS                    │
│                                                              │
│  CRIAÇÃO:                                                    │
│  ├── generated_by (UUID do usuário)                          │
│  ├── created_at (TIMESTAMPTZ)                                │
│  ├── record_date, record_time (data/hora do servidor)        │
│  └── audit_log: OFC_CREATE                                   │
│                                                              │
│  EDIÇÃO:                                                     │
│  ├── updated_at (TIMESTAMPTZ)                                │
│  ├── edit_count (contador de edições)                        │
│  ├── ofc_edit_log: (campo, old_value, new_value, who, when)  │
│  └── audit_log: OFC_EDIT                                     │
│                                                              │
│  CANCELAMENTO:                                               │
│  ├── deleted_by (UUID do usuário)                            │
│  ├── deleted_at (TIMESTAMPTZ)                                │
│  ├── cancel_reason (TEXT)                                    │
│  ├── is_deleted = TRUE (soft delete)                         │
│  └── audit_log: OFC_CANCEL                                   │
│                                                              │
│  NUNCA: exclusão física. Sempre soft delete.                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 15. Estratégia de Cancelamento Lógico

### 15.1 Regras

- Apenas Gestor e Admin podem cancelar
- Cancelamento = soft delete (is_deleted = TRUE)
- Motivo do cancelamento é obrigatório
- Registro NUNCA é excluído fisicamente
- OFS cancelada não aparece em métricas nem consultas padrão
- Apenas Admin pode restaurar (is_deleted = FALSE)
- Auditoria registrada como CRITICAL

### 15.2 Código

```python
async def cancel_ofc(ofc_id: UUID, reason: str, user: User, db: AsyncSession):
    OFS = await db.get(OfcRecord, ofc_id)
    if not OFS or OFS.is_deleted:
        raise HTTPException(404, "Registro não encontrado")
    if user.role not in ("gestor", "admin"):
        raise HTTPException(403, "Apenas Gestor e Admin podem cancelar")
    if not reason or not reason.strip():
        raise HTTPException(422, "Motivo do cancelamento é obrigatório")
    
    OFS.is_deleted = True
    OFS.deleted_at = datetime.now(timezone.utc)
    OFS.deleted_by = user.id
    OFS.cancel_reason = reason.strip()
    OFS.status = "cancelado"
    OFS.updated_at = datetime.now(timezone.utc)
    
    await db.commit()
    
    # Auditoria
    await registrar_auditoria(db, user.id, "OFC_CANCEL", "ofc_records",
        str(ofc_id), {"motivo": reason}, severity="WARN")
```

---

## 16. Estratégia de Logs

### 16.1 Política de Retenção

| Tipo | Retenção | Destino |
|------|----------|---------|
| audit_logs (online) | 90 dias | Tabela principal |
| audit_logs (arquivo) | 5 anos | ZIP criptografado em disco |
| app logs | 30 dias | Arquivo rotativo |
| nginx access log | 30 dias | Arquivo rotativo |
| nginx error log | 90 dias | Arquivo rotativo |
| revoked_tokens | Até expirar | Cleanup diário |

### 16.2 Integridade dos Logs

- Tabela `audit_logs` é **imutável** (revogado UPDATE/DELETE para role da aplicação)
- Trigger impede UPDATE/DELETE diretamente
- Hash encadeado entre registros (prev_checksum)
- Arquivos ZIP de archive possuem `.sha256` de verificação

---

## 17. Estratégia de Segurança Operacional

### 17.1 Checklist

| Camada | Medida | Status |
|--------|--------|:---:|
| **Senhas** | bcrypt cost 12, mínimo 12 caracteres | ✅ |
| **Tokens** | JWT HS256, 15min access + 7d refresh | ✅ |
| **Lockout** | 5 falhas → 30 minutos | ✅ |
| **RBAC** | 4 perfis com data scoping | ✅ |
| **Auditoria** | Todas ações críticas registradas | ✅ |
| **Soft delete** | Nunca exclusão física | ✅ |
| **Headers** | CSP, X-Frame-Options, X-XSS-Protection | ✅ |
| **HTTPS** | Fase 2 (certificado autoassinado) | ⬜ |
| **Docker** | non-root, read_only, cap_drop ALL | ✅ |
| **Banco** | Role mínima, sem superuser para app | ✅ |
| **Backup** | Diário automático, criptografado | ✅ |

### 17.2 O Que NÃO Precisa de Proteção Adicional

| Risco | Por que é inexistente |
|-------|----------------------|
| File upload injection | Sistema 100% textual, zero upload |
| XSS via upload (SVG/HTML) | Sem upload de arquivos |
| CSRF tradicional | API REST usa header Authorization (não cookies) |
| SSRF | Intranet sem acesso externo |
| CDN/Supply chain | Zero dependências externas |

---

## 18. Recomendações Finais

### 18.1 Para a Sprint 0 (Setup)

1. Criar migration inicial com todas as tabelas de auth
2. Configurar JWT_SECRET como variável de ambiente (nunca hardcoded)
3. Criar seed do admin com senha forte
4. Implementar middleware de auth antes de qualquer endpoint de negócio
5. Testar fluxo completo: login → token → refresh → logout → bloqueio

### 18.2 Preparação para Futuro (NÃO implementar agora)

| Funcionalidade | Quando |
|---------------|--------|
| HTTPS com certificado autoassinado | Fase 2 |
| LDAP/Active Directory | Pós-MVP |
| Single Sign-On (SSO) | Cloud |
| MFA (2 fatores) | Cloud |
| Rotação automática de JWT_SECRET | Cloud |
| Rate limiting distribuído (Redis) | Cloud |

### 18.3 Configurações Críticas

```python
# Valores que NUNCA devem ser alterados sem avaliação de segurança:
BCRYPT_ROUNDS = 12          # Abaixo de 10 é inseguro
ACCESS_EXPIRE = 900          # Acima de 30min é inseguro para access token
LOCKOUT_ATTEMPTS = 5         # Acima de 10 facilita brute-force
JWT_ALGORITHM = "HS256"      # RS256 requer chave assimétrica
```

---

**Documento gerado em 13/05/2026.**
