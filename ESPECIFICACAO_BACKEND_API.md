# ESPECIFICAÇÃO COMPLETA DO BACKEND/API — MVP

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Stack:** FastAPI + Python 3.12 + SQLAlchemy 2.0 async + PostgreSQL 16  
**Data:** 13/05/2026  

---

## Sumário

1. [Stack Final e Justificativa](#1-stack-final-e-justificativa)
2. [Arquitetura de Módulos](#2-arquitetura-de-módulos)
3. [Estrutura de Pastas](#3-estrutura-de-pastas)
4. [Padrão de Camadas](#4-padrão-de-camadas)
5. [Endpoints e Payloads](#5-endpoints-e-payloads)
6. [Autenticação e Autorização](#6-autenticação-e-autorização)
7. [Modelos e Schemas](#7-modelos-e-schemas)
8. [Serviços e Regras de Negócio](#8-serviços-e-regras-de-negócio)
9. [Relatórios e Exportações](#9-relatórios-e-exportações)
10. [Auditoria](#10-auditoria)
11. [Estratégia de Transações](#11-estratégia-de-transações)
12. [Configurações](#12-configurações)
13. [Plano de Testes](#13-plano-de-testes)
14. [Critérios de Aceite do Backend](#14-critérios-de-aceite-do-backend)

---

## 1. Stack Final e Justificativa

### 1.1 Decisão: FastAPI (Python 3.12)

| Critério | NestJS (Node) | FastAPI (Python) | Vencedor |
|----------|:---:|:---:|:---:|
| Performance req/s | 25-40k | 18-30k | NestJS — irrelevante (< 50 usuários) |
| Geração PDF | Puppeteer ~300MB | **WeasyPrint ~15MB** | **FastAPI** |
| Gráficos server-side | chartjs-node-canvas | **matplotlib** | **FastAPI** |
| Empacotamento offline | ~500MB node_modules | **~80MB** pip download | **FastAPI** |
| Curva aprendizado | 8 conceitos | **4 conceitos** | **FastAPI** |

**Justificativa:** O sistema é um monolito modular offline com 44 endpoints e 2 PDFs com gráficos. O gargalo é a geração de PDFs (2-15s), não throughput HTTP. WeasyPrint (15MB, zero browser) é 20x menor que Puppeteer (300MB Chromium). O ecossistema Python (WeasyPrint + matplotlib + openpyxl + Jinja2) é imbatível para relatórios corporativos. O empacotamento offline via `pip download` gera 80MB de wheels — transportável por pendrive para o servidor de intranet.

### 1.2 Stack Completa

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Framework | FastAPI | 0.111+ |
| Server | Uvicorn | 0.29+ (4 workers) |
| ORM | SQLAlchemy | 2.0+ (async) |
| Migrations | Alembic | 1.13+ |
| Validação | Pydantic | 2.x |
| Auth | python-jose (JWT) + passlib (bcrypt) | 3.x / 1.7+ |
| PDF | WeasyPrint + Jinja2 | 61+ / 3.x |
| Gráficos | matplotlib | 3.8+ |
| Excel | openpyxl | 3.1+ |
| Agendador | APScheduler | 3.x |
| Rate Limiting | slowapi | 0.1+ |
| Testes | pytest + pytest-asyncio + httpx | 8.x |

---

## 2. Arquitetura de Módulos

```
┌──────────────────────────────────────────────────────────────────┐
│                       main.py (FastAPI app)                       │
│         lifespan: init_scheduler + engine connect                 │
│         middlewares: CORS, AuthMiddleware, AuditMiddleware         │
└───┬────────┬────────┬────────┬────────┬────────┬────────┬────────┘
    │        │        │        │        │        │        │
    ▼        ▼        ▼        ▼        ▼        ▼        ▼
┌──────┐┌──────┐┌──────┐┌──────┐┌──────┐┌──────┐┌──────────┐
│ Auth ││Users ││OFS   ││Metric││Report││Audit ││Backup    │
│JWT   ││CRUD  ││CRUD  ││Calc  ││PDF   ││Log   ││Scheduler │
│bcrypt││RBAC  ││Edit  ││Chart ││Excel ││Query ││pg_dump   │
│Lock  ││      ││Cancel││Status││Jinja2││Immute││Restore   │
└──────┘└──────┘└──────┘└──────┘└──────┘└──────┘└──────────┘
    │        │        │        │        │        │        │
    └────────┴────────┴────────┴────────┴────────┴────────┘
                              │
                    ┌─────────▼─────────┐
                    │  SQLAlchemy 2.0   │
                    │  AsyncSession     │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  PostgreSQL 16    │
                    │  12 tabelas       │
                    └───────────────────┘
```

### Responsabilidades

| Módulo | Responsabilidade |
|--------|-----------------|
| **Auth** | Login, refresh/revoke JWT, bcrypt, lockout (5 falhas/30min), change password com histórico |
| **Users** | CRUD de usuários, ativar/desativar, listar com filtros |
| **Companies** | CRUD de empresas, dropdown para formulário OFS |
| **Contracts** | CRUD de contratos |
| **Targets** | CRUD de metas semanais, busca da meta vigente |
| **OFS Records** | Criação com código automático, snapshots, edição com janela 24/48h, cancelamento lógico |
| **Consulta** | Filtros dinâmicos (15 params), full-text search, export CSV |
| **Metrics** | 10 indicadores, status OK/ATENÇÃO/ALERTA, 4 gráficos, rankings |
| **Reports** | PDF individual, PDF semanal (WeasyPrint + matplotlib), Excel (openpyxl) |
| **Audit** | Log imutável de todas as ações, consulta paginada Admin |
| **Backup** | Automático diário 03:00 (APScheduler), manual, restore, rotação 30 dias |

---

## 3. Estrutura de Pastas

```
backend/
├── app/
│   ├── main.py                  # FastAPI app, lifespan, middlewares, routers
│   ├── api/                     # Routers (thin — só recebe/valida/delega)
│   │   ├── deps.py              # get_current_user, require_role, get_data_scope
│   │   ├── auth.py              # POST login, refresh, logout, GET me, PUT change-password
│   │   ├── users.py             # CRUD /users
│   │   ├── companies.py         # CRUD /companies
│   │   ├── contracts.py         # CRUD /contracts
│   │   ├── targets.py           # CRUD /targets
│   │   ├── ofc_records.py       # CRUD /OFS-records + cancel + pdf
│   │   ├── consulta.py          # GET /consulta + CSV export
│   │   ├── metrics.py           # GET /metrics/week, charts, rankings, evolution
│   │   ├── reports.py           # GET /reports/*/pdf, */excel
│   │   ├── audit.py             # GET /audit-logs
│   │   └── backup.py            # GET /backup/status, POST manual/restore
│   │
│   ├── services/                # Business logic (transacional)
│   │   ├── auth_service.py      # JWT, bcrypt, lockout
│   │   ├── user_service.py      # CRUD + password history
│   │   ├── ofc_service.py       # Create, update, cancel, restore, list
│   │   ├── metrics_service.py   # calculate_weekly_metrics, evolution, ranking
│   │   ├── chart_service.py     # matplotlib → PNG base64 (4 charts)
│   │   ├── pdf_service.py       # Jinja2 + WeasyPrint → PDF
│   │   ├── excel_service.py     # openpyxl → XLSX
│   │   ├── audit_service.py     # write_audit_log, query
│   │   └── backup_service.py    # pg_dump, pg_restore, rotation
│   │
│   ├── models/                  # SQLAlchemy 2.0 ORM (Mapped[])
│   │   ├── base.py              # DeclarativeBase
│   │   ├── company.py           # companies
│   │   ├── user.py              # users
│   │   ├── contract.py          # contracts
│   │   ├── target.py            # targets
│   │   ├── ofc_record.py        # ofc_records + OfcEditLog
│   │   ├── audit_log.py         # audit_logs
│   │   ├── password_history.py  # password_history
│   │   ├── revoked_token.py     # revoked_tokens
│   │   ├── report.py            # reports
│   │   ├── system_param.py      # system_params
│   │   └── ofc_seq_control.py   # ofc_seq_control
│   │
│   ├── schemas/                 # Pydantic v2 (request/response)
│   │   ├── auth.py, user.py, company.py, contract.py
│   │   ├── target.py, OFS.py, metrics.py, report.py, audit.py
│   │   ├── common.py            # PaginatedResponse[T], ErrorResponse
│   │   └── enums.py             # TurnoEnum, TipoObservacaoEnum, StatusEnum
│   │
│   ├── core/                    # Cross-cutting
│   │   ├── config.py            # Pydantic BaseSettings
│   │   ├── security.py          # JWT, bcrypt, RBAC
│   │   ├── permissions.py       # Data scoping, edit windows, can_edit/can_cancel
│   │   ├── middleware.py         # AuthMiddleware
│   │   ├── audit.py             # @audit_action decorator + write_audit_log
│   │   ├── edit_tracker.py      # Diff fields → ofc_edit_log
│   │   ├── scheduler.py         # APScheduler backup 03:00
│   │   └── exceptions.py        # AppError handlers
│   │
│   └── db/
│       ├── session.py           # create_async_engine + get_db dependency
│       └── base.py              # DeclarativeBase
│
├── alembic/                     # Migrations versionadas
├── migrations/                  # SQL scripts (docker-entrypoint)
├── templates/                   # Jinja2 HTML → PDF
│   ├── _base.html
│   ├── individual_ofc.html
│   └── weekly_metrics.html
├── static/                      # Fontes, logo (offline)
├── tests/                       # 85 testes em 9 arquivos
├── Dockerfile                   # Multi-stage offline
├── requirements.txt
└── .env.example
```

---

## 4. Padrão de Camadas

```
Router (thin)  →  Service (business logic)  →  Model (ORM)  →  DB
   │                      │                        │
   │ recebe/valida        │ regras, transações,    │ Mapped columns
   │ chama service        │ auditoria, diff        │ relationships
```

### Exemplo: Criar OFS

```python
# Router (api/ofc_records.py) — THIN
@router.post("", response_model=OfcResponse, status_code=201)
async def criar_ofc(
    payload: OfcCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    OFS = await create_ofc_record(payload, current_user, db)
    await db.commit()
    return OFS

# Service (services/ofc_service.py) — BUSINESS LOGIC
async def create_ofc_record(payload, user, db) -> OfcRecord:
    OFS = OfcRecord(
        id=uuid4(),
        record_date=payload.data_registro,
        observed_name=payload.nome_observado,
        company_id=payload.empresa_observada_id,
        generated_by=user.id,
        type=payload.tipo_observacao,
        behavior_observed=payload.comportamento_observado,
        status="ativo",
        # Triggers SQL: código OFS-AAAA-SS-NNNN, data parts, updated_at
    )
    db.add(OFS)
    # Audit log (mesma transação)
    db.add(AuditLog(action="OFC_CREATE", user_id=user.id, resource="ofc_records",
                     resource_id=str(OFS.id), severity="INFO"))
    return OFS

# Model (models/ofc_record.py) — ORM
class OfcRecord(Base):
    __tablename__ = "ofc_records"
    id: Mapped[UUID] = mapped_column(UUID, primary_key=True, default=uuid4)
    codigo: Mapped[str] = mapped_column(String(17), unique=True)
    record_date: Mapped[date] = mapped_column(Date, nullable=False)
    ...
```

---

## 5. Endpoints e Payloads

### 5.1 Resumo (44 Endpoints)

| Módulo | Endpoints | Principais |
|--------|:---:|-----------|
| Auth | 3 | POST login, POST logout, GET me |
| Users | 6 | CRUD + status + password |
| Companies | 5 | CRUD + status |
| Contracts | 5 | CRUD + status |
| Targets | 4 | CRUD + current |
| OFS Records | 6 | CRUD + cancel + pdf |
| Consulta | 2 | GET consulta + export CSV |
| Metrics | 7 | week, month, company-ranking, user-ranking, evolution, top-behaviors, deviations |
| Reports | 5 | OFS/pdf, week/pdf, month/pdf, week/excel, month/excel |
| Audit | 1 | GET audit-logs |
| System | 2 | GET/PUT system-params |
| **Total** | **44** | |

### 5.2 Payloads Essenciais

**POST /api/auth/login:**
```json
// Request
{ "username": "carlos.oliveira", "password": "Senha@123" }

// Response 200
{ "access_token": "eyJ...", "refresh_token": "eyJ...", "token_type": "bearer",
  "expires_in": 900, "user": { "id": "uuid", "username": "carlos.oliveira",
  "full_name": "Carlos Oliveira", "role": "supervisor", "company_id": 1 } }

// Response 401
{ "success": false, "error": { "code": "INVALID_CREDENTIALS", "message": "Credenciais inválidas" } }
```

**POST /api/OFS-records:**
```json
// Request
{ "empresa_observada_id": 1, "nome_observado": "Carlos Silva",
  "atividade_observada": "Controle de acesso na portaria", "local_observado": "Portaria 01",
  "turno": "Diurno", "tipo_observacao": "Positivo/Seguro",
  "comportamento_observado": "Uso correto de procedimento de abordagem",
  "observacao_complementar": "Colaborador atento aos protocolos" }

// Response 201
{ "id": "uuid", "codigo": "OFS-2026-20-0001", "data_registro": "2026-05-13",
  "hora_registro": "14:30:00", "status_registro": "Gerado", ... }
```

**GET /api/metrics/week?week_start=2026-05-11&company_id=1:**
```json
// Response 200
{ "periodo": { "ano": 2026, "semana": 20, "data_inicio": "2026-05-11", "data_fim": "2026-05-17" },
  "indicadores": { "pessoas_ativas": 85, "ofc_programadas": 255, "ofc_realizadas": 230,
    "aderencia_percentual": 90.2, "positivas": 195, "negativas": 35,
    "percentual_seguro": 84.8, "percentual_desvio": 15.2,
    "usuarios_ativos": 12, "media_ofc_usuario": 19.2 },
  "status": "OK", "status_cor": "#22C55E" }
```

### 5.3 Padrão de Paginação

```json
// Request: ?page=1&page_size=25
// Response:
{ "data": [...],
  "pagination": { "page": 1, "page_size": 25, "total": 47, "total_pages": 2 } }
```

### 5.4 Padrão de Erro

```json
{ "success": false,
  "error": { "code": "VALIDATION_ERROR", "message": "Dados inválidos",
    "details": [{ "field": "nome_observado", "error": "Mínimo 3 caracteres" }] },
  "timestamp": "2026-05-13T14:30:00Z" }
```

### 5.5 Códigos de Erro por Situação

| Código | Situação | Exemplo |
|:---:|-----------|---------|
| 400 | Requisição malformada | JSON inválido |
| 401 | Não autenticado | Token ausente ou expirado |
| 403 | Não autorizado | Perfil sem permissão |
| 404 | Recurso não encontrado | OFS inexistente |
| 409 | Conflito | Optimistic lock, janela expirada |
| 422 | Validação | Campo obrigatório faltando |
| 423 | Bloqueado | Lockout após 5 falhas |
| 429 | Rate limit | Muitas requisições |
| 500 | Erro interno | Exceção não tratada |

---

## 6. Autenticação e Autorização

### 6.1 JWT Configuration

| Parâmetro | Valor |
|-----------|-------|
| Algoritmo | HS256 |
| Secret | 32+ caracteres (env var) |
| Access Token TTL | 15 minutos |
| Refresh Token TTL | 7 dias |
| Claims | `sub`, `role`, `type`, `jti`, `exp`, `iat` |

### 6.2 Dependências FastAPI (deps.py)

```python
# Extrai e valida JWT, busca usuário no banco
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User: ...

# Factory: exige um ou mais perfis
def require_role(*roles: str) -> Callable: ...

# Retorna filtros de visibilidade por perfil
async def get_data_scope(current_user: User = Depends(get_current_user)) -> dict: ...
```

### 6.3 RBAC — Matriz de Permissões

| Ação | Observador | Supervisor | Gestor | Admin |
|------|:---:|:---:|:---:|:---:|
| Criar OFS | ✅ | ✅ | ✅ | ✅ |
| Ver OFCs | 🔹 seus | 🔸 empresa | ✅ todos | ✅ todos |
| Editar OFS | 🔹⏱ 24h | 🔸⏱ 48h | ✅ | ✅ |
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Restaurar OFS | ❌ | ❌ | ❌ | ✅ |
| Métricas | ❌ | 🔸 empresa | ✅ | ✅ |
| PDF semanal | ❌ | ❌ | ✅ | ✅ |
| Gerenciar usuários | ❌ | ❌ | 🔸 empresa | ✅ |
| Gerenciar empresas | ❌ | ❌ | ❌ | ✅ |
| Auditoria | ❌ | ❌ | ❌ | ✅ |
| Backup | ❌ | ❌ | ❌ | ✅ |

- 🔹 Escopo: apenas registros próprios
- 🔸 Escopo: apenas registros da empresa
- ⏱ Com janela de tempo

### 6.4 Lockout

```
5 tentativas falhas → locked_until = NOW() + 30 minutos
Reset ao logar com sucesso
Verificação em todo POST /api/auth/login
```

### 6.5 Password Policy

- Mínimo 12 caracteres
- 1 maiúscula + 1 minúscula + 1 dígito + 1 especial
- bcrypt cost factor 12
- Histórico: últimas 6 senhas bloqueadas
- Expiração: 90 dias

---

## 7. Modelos e Schemas

### 7.1 Modelos SQLAlchemy (12 tabelas)

| Modelo | Tabela | Principais Colunas |
|--------|--------|--------------------|
| `Company` | companies | id, name, is_custom, is_active |
| `User` | users | id UUID, username, password_hash, role, company_id, is_active, locked_until |
| `Contract` | contracts | id, name, description, is_active |
| `Target` | targets | id, company_id, contract_id, week_start, active_people, weekly_target |
| `OfcRecord` | ofc_records | id UUID, codigo, todos os snapshots e campos da observação |
| `OfcEditLog` | ofc_edit_log | id, ofc_record_id, edited_by, field_changed, old_value, new_value |
| `AuditLog` | audit_logs | id, user_id, action, resource, details JSONB, severity |
| `PasswordHistory` | password_history | id, user_id, password_hash, changed_at |
| `RevokedToken` | revoked_tokens | jti PK, user_id, expires_at, revoked_at |
| `Report` | reports | id UUID, type, parameters JSONB, file_path, generated_by |
| `SystemParam` | system_params | id, chave UNIQUE, valor, descricao |
| `OfcSeqControl` | ofc_seq_control | ano, semana PK, last_seq |

### 7.2 Schemas Pydantic (Validação)

- `OfcCreateRequest`: 9 campos + validators (data futura, "Outros")
- `OfcUpdateRequest`: campos opcionais + `updated_at` para optimistic lock
- `PaginatedResponse[T]`: genérico com data, page, page_size, total, total_pages
- `WeeklyMetricsResponse`: 10 indicadores + status + cor
- Enums: `UserRole`, `TipoObservacao`, `Turno`, `StatusRegistro`, `Severity`

---

## 8. Serviços e Regras de Negócio

### 8.1 ofc_service.py — Funções Principais

```python
async def create_ofc_record(payload, user, db) -> OfcRecord:
    """Cria OFS. Snapshots preenchidos. Trigger gera código."""
    
async def update_ofc_record(ofc_id, payload, user, db) -> tuple[OfcRecord, list]:
    """Edita OFS. Verifica permissão, janela, optimistic lock. Registra ofc_edit_log."""
    
async def cancel_ofc(ofc_id, reason, user, db) -> OfcRecord:
    """Soft delete. Apenas Gestor/Admin. Motivo obrigatório."""
    
async def restore_ofc(ofc_id, user, db) -> OfcRecord:
    """Restaura OFS cancelada. Apenas Admin. Auditado como CRITICAL."""

async def list_ofcs(filters, user, db) -> tuple[list, int]:
    """Lista com filtros dinâmicos e data scoping."""
```

### 8.2 Data Scoping (aplicado em todas as queries)

```python
def apply_scope(query, user):
    if user.role == 'observador':
        return query.where(OfcRecord.generated_by == user.id)
    elif user.role == 'supervisor':
        return query.where(OfcRecord.company_id == user.company_id)
    return query  # gestor, admin: sem filtro
```

### 8.3 metrics_service.py

```python
async def calculate_weekly_metrics(week_start, company_id, db) -> dict:
    """10 indicadores + status. Usa CTE SQL. Cache TTLCache 5min."""

async def get_weekly_evolution(company_id, weeks, db) -> list:
    """Aderência por semana. Últimas N semanas."""

async def get_company_ranking(week_start, db) -> list:
    """Ranking de empresas por aderência."""
```

---

## 9. Relatórios e Exportações

### 9.1 Pipeline de PDF

```
1. Busca dados no PostgreSQL
2. chart_service.py → matplotlib → PNG (BytesIO)
3. PNG → base64
4. Jinja2 template + dados + base64 images
5. WeasyPrint HTML → PDF bytes
6. Salva em /app/reports/ (volume Docker)
7. Registra na tabela reports
8. Audit log: GERAR_PDF
9. Retorna StreamingResponse (application/pdf)
```

### 9.2 PDFs do MVP

| PDF | Template | Gráficos | Tempo |
|-----|----------|:---:|:---:|
| Individual OFS | `individual_ofc.html` | 0 | < 2s |
| Métricas da Semana | `weekly_metrics.html` | 4 | < 15s |

### 9.3 Excel (openpyxl)

| Aba | Conteúdo |
|-----|----------|
| Resumo | 10 indicadores com formatação |
| Consolidado | Tabela por empresa com cores por faixa |
| Registros Base | Dados brutos com autofiltro |

### 9.4 Logo

Carregado 1x como singleton no módulo → convertido para base64 → embedado no HTML do template. Zero dependência de path absoluto.

---

## 10. Auditoria

### 10.1 Eventos Registrados

| Evento | Ação | Severidade |
|--------|------|:---:|
| Login com sucesso | `LOGIN_SUCCESS` | INFO |
| Login falhou | `LOGIN_FAILED` | WARNING |
| OFS criado | `OFC_CREATE` | INFO |
| OFS editado | `OFC_UPDATE` | WARNING |
| OFS cancelado | `OFC_CANCEL` | WARNING |
| OFS restaurado | `OFC_RESTORE` | CRITICAL |
| PDF gerado | `GERAR_PDF` | INFO |
| Excel exportado | `EXPORTAR_EXCEL` | INFO |
| Backup manual | `BACKUP_MANUAL` | INFO |
| Backup restaurado | `BACKUP_RESTORE` | CRITICAL |

### 10.2 Implementação

```python
# Decorator nos endpoints
@router.post("/api/OFS-records")
@audit_action("OFC_CREATE", "ofc_records", "INFO")
async def criar_ofc(...): ...

# Middleware captura 401/403 automaticamente
class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        if response.status_code in (401, 403):
            # Registra PERMISSION_DENIED em background
            ...
        return response
```

### 10.3 Imutabilidade

- Tabela `audit_logs` tem trigger que impede UPDATE/DELETE
- Apenas INSERT permitido
- Role da aplicação sem permissão de UPDATE/DELETE

---

## 11. Estratégia de Transações

```python
# Session Factory
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()    # Sucesso → commit
        except Exception:
            await session.rollback()  # Erro → rollback
            raise

# Operação multi-tabela (mesma transação)
async def create_ofc(payload, user, db):
    OFS = OfcRecord(...)
    db.add(OFS)
    await db.flush()  # Trigger gera código
    
    audit = AuditLog(action="OFC_CREATE", ...)
    db.add(audit)
    
    # Commit acontece no get_db() ao final do request
    return OFS
```

**Pool de Conexões:**
- `pool_size=10`, `max_overflow=20`
- `pool_pre_ping=True` (verifica conexão antes de usar)
- `pool_recycle=1800` (recicla a cada 30 min)

---

## 12. Configurações

### 12.1 Variáveis de Ambiente (.env)

```bash
# JWT
JWT_SECRET=<32+ caracteres aleatórios>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7

# Senhas
PASSWORD_MIN_LENGTH=12
PASSWORD_EXPIRATION_DAYS=90
MAX_FAILED_ATTEMPTS=5
LOCKOUT_MINUTES=30

# Banco
DB_HOST=db
DB_PORT=5432
DB_USER=ofs_app
DB_PASSWORD=<senha forte>
DB_NAME=ofs_db

# Backup
BACKUP_DIR=/app/backups
BACKUP_RETENTION_DAILY=30

# Rate Limiting
RATE_LIMIT_DEFAULT=100/minute
RATE_LIMIT_LOGIN=5/minute

# Logging
LOG_LEVEL=INFO
```

### 12.2 Settings (Pydantic)

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    JWT_SECRET: str
    DB_PASSWORD: str
    # ... todas as variáveis acima
    
    @property
    def database_url(self) -> str:
        return f"postgresql+asyncpg://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
    
    class Config:
        env_file = ".env"

settings = Settings()
```

---

## 13. Plano de Testes

### 13.1 Estrutura (85 testes em 9 arquivos)

```
tests/
├── conftest.py            # Fixtures: async client, test DB, auth headers por perfil
├── test_auth.py           # 13 testes — login, logout, refresh, lockout
├── test_users.py          #  8 testes — change-password, CRUD, permissões
├── test_companies.py      #  3 testes — isolamento, dropdown
├── test_ofc_records.py    # 23 testes — CRUD completo + regras
├── test_metrics.py        # 10 testes — cálculos, status, rankings
├── test_reports.py        #  6 testes — PDF, Excel, 404
├── test_audit.py          #  9 testes — logs, filtros, integridade
└── test_permissions.py    # 13 testes — RBAC 4 perfis
```

### 13.2 Cobertura por Categoria

| Categoria | Testes | Cenários Chave |
|-----------|:---:|----------------|
| Auth | 13 | Login 200/401/403/423, refresh, logout, token expirado |
| OFS CRUD | 23 | Criar, editar (24h/48h), cancelar, optimistic lock 409, data scoping |
| Métricas | 10 | 10 indicadores, status OK/ATENÇÃO/ALERTA, SEM_META, rankings |
| Permissões | 13 | Todos os 4 perfis × ações críticas |
| PDF | 6 | Individual, semanal, Content-Type, 404 |
| Auditoria | 9 | Logs, filtros, imutabilidade |

### 13.3 Execução

```bash
cd backend
pytest tests/ -v                    # Todos os testes
pytest tests/test_ofc_records.py -v # Apenas OFS
pytest tests/ -v -k "test_permiss"  # Apenas permissões
```

---

## 14. Critérios de Aceite do Backend

### 14.1 Autenticação

- [ ] Login retorna JWT access + refresh tokens
- [ ] Access token expira em 15 minutos
- [ ] Refresh token renova sem novo login
- [ ] Logout revoga refresh token
- [ ] 5 falhas bloqueiam por 30 minutos
- [ ] Senha validada (12 chars, complexidade)
- [ ] Histórico de 6 senhas bloqueia reuso

### 14.2 OFS/OFS

- [ ] Criação retorna 201 com código OFS-AAAA-SS-NNNN
- [ ] Snapshots do usuário preenchidos automaticamente
- [ ] "Outros" sem nome → 422
- [ ] Edição com optimistic lock → 409 se conflito
- [ ] Janela 24h/48h respeitada
- [ ] Cancelamento exige motivo → 422 se ausente
- [ ] DELETE físico bloqueado por trigger
- [ ] Data scoping correto por perfil

### 14.3 Métricas

- [ ] 10 indicadores calculados corretamente
- [ ] Status OK (≥100%), ATENÇÃO (80-99%), ALERTA (<80%)
- [ ] SEM_META quando não há meta cadastrada
- [ ] OFCs canceladas não entram no cálculo

### 14.4 Relatórios

- [ ] PDF individual gerado em < 2s
- [ ] PDF semanal gerado em < 15s com 4 gráficos
- [ ] Logo SD no cabeçalho
- [ ] Rodapé com data/hora e página
- [ ] Excel com 3 abas formatadas
- [ ] Auditoria registrada em toda exportação

### 14.5 Segurança e Auditoria

- [ ] Nenhum endpoint aceita sem token (exceto públicos)
- [ ] RBAC aplicado em todos os endpoints
- [ ] audit_logs imutável (sem UPDATE/DELETE)
- [ ] Toda ação crítica registrada em auditoria
- [ ] Zero upload de arquivos
- [ ] Zero dependência de APIs externas

### 14.6 Performance

- [ ] Login < 200ms
- [ ] Criar OFS < 80ms
- [ ] Listar OFCs (25/página) < 150ms
- [ ] Métricas semanais < 300ms
- [ ] PDF individual < 2s
- [ ] PDF semanal < 15s

### 14.7 Testes

- [ ] 85+ testes passando
- [ ] Cobertura de todos os endpoints
- [ ] Cobertura de todos os perfis (RBAC)
- [ ] Cobertura de edge cases (divisão por zero, sem meta, sem registros)

---

**Documento gerado em 13/05/2026.**

## Todos os Documentos do Projeto

| # | Arquivo | Tema |
|---|---------|------|
| 1 | `PLANO_MESTRE_SISTEMA_OFS.md` | Arquitetura geral |
| 2 | `PLANO_TECNICO_MVP_OFS.md` | Escopo MVP |
| 3 | `MODELAGEM_TECNICA_BD_API_MVP.md` | Modelagem inicial |
| 4 | `ESPECIFICACAO_UX_UI_MVP.md` | Interface |
| 5 | `ESPECIFICACAO_RELATORIOS_PDF_MVP.md` | Relatórios |
| 6 | `ARQUITETURA_INFRA_DEPLOY_SEGURANCA.md` | Infraestrutura |
| 7 | `PLANO_DESENVOLVIMENTO_AGENTES.md` | Sprints |
| 8 | `ARQUITETURA_CONSOLIDADA_FINAL.md` | Revisão final |
| 9 | `ESPECIFICACAO_AUTENTICACAO_SEGURANCA.md` | Auth |
| 10 | `ESPECIFICACAO_METRICAS_SEMANA.md` | Métricas |
| 11 | `ESPECIFICACAO_MODULO_OFC_OFS.md` | OFS/OFS |
| 12 | `ESPECIFICACAO_BANCO_DADOS.md` | Banco de Dados |
| 13 | `ESPECIFICACAO_BACKEND_API.md` | **Backend/API** ← este documento |
