# PLANO TÉCNICO DO MVP — Sistema de Feedback Comportamental OFS/OFS

**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  
**Status:** Plano de Construção  

---

## 1. Escopo do MVP

### O que ENTRA no MVP

| # | Módulo | Funcionalidades |
|---|--------|----------------|
| 1 | **Login Local** | Login/senha, JWT, 4 perfis, sessão segura, usuário identificado em todos os registros |
| 2 | **Cadastros Básicos** | CRUD de Usuários, Empresas, Contratos, Metas (Admin/Gestor) |
| 3 | **Geração de OFS/OFS** | Formulário completo com campos automáticos + manuais, 15 empresas em dropdown, regra "Outros" |
| 4 | **Consulta Individual** | Filtros por nº OFS, período, usuário, empresa, local, turno, tipo, status + tabela de resultados |
| 5 | **MÉTRICAS DA SEMANA** | Painel com filtros (semana/mês/ano/contrato/empresa/turno), 10 indicadores, status OK/ATENÇÃO/ALERTA |
| 6 | **Gráficos Mínimos** | 5 gráficos: Programado x Realizado, Positivo x Negativo, OFS por Empresa, OFS por Usuário, Evolução Semanal |
| 7 | **PDFs** | PDF individual da OFS/OFS + PDF MÉTRICAS DA SEMANA com identidade visual corporativa |
| 8 | **Auditoria** | Log de criação, edição, cancelamento com motivo, timestamps e usuário responsável |
| 9 | **Backup** | Backup diário automático do banco + PDFs, retenção 30 dias, restauração simples |

### O que FICA FORA do MVP

| Funcionalidade | Motivo |
|----------------|--------|
| Relatório mensal completo | PDF semanal já cobre o essencial; mensal será Fase 3 |
| Relatório por empresa agregado | Fase 3 |
| Gráfico de evolução mensal | Fase 3 |
| Top comportamentos no PDF | Fase 3 |
| Exportação CSV da consulta | Fase 2 (consulta visual já atende MVP) |
| Dashboard principal com cards de resumo | Fase 2 |
| Tela "Salvar e Novo" para registros em lote | Fase 2 |
| Ranking de usuários geradores | Fase 3 |
| Filtro por contrato nas métricas (backend pronto, frontend Fase 2) | Fase 2 |
| Modo escuro | Pós-MVP |
| Internacionalização | Pós-MVP |
| Notificações por email | Pós-MVP |
| Aplicativo mobile nativo | Pós-MVP |
| Assinatura digital nos PDFs | Pós-MVP |

---

## 2. Arquitetura Técnica Final Recomendada

### 2.1 Diagrama de Implantação

```
┌──────────────────────────────────────────────────────────────────┐
│                    SERVIDOR INTERNO (Windows/Linux)               │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    DOCKER (docker-compose)                    │ │
│  │                                                               │ │
│  │  ┌──────────┐   ┌──────────────┐   ┌──────────────────────┐ │ │
│  │  │  nginx   │   │   backend    │   │    postgresql        │ │ │
│  │  │  :80     │──▶│   :8000      │──▶│    :5432             │ │ │
│  │  │          │   │              │   │                      │ │ │
│  │  │ static   │   │ FastAPI      │   │ PostgreSQL 16        │ │ │
│  │  │ files    │   │ Uvicorn      │   │                      │ │ │
│  │  │ + proxy  │   │ SQLAlchemy   │   │ Vol: pgdata          │ │ │
│  │  └──────────┘   │ APScheduler  │   └──────────────────────┘ │ │
│  │                  │ WeasyPrint   │                             │ │
│  │                  │ matplotlib   │   ┌──────────────────────┐ │ │
│  │                  └──────────────┘   │     volumes          │ │ │
│  │                                     │  ./backups/          │ │ │
│  │                                     │  ./reports/          │ │ │
│  │                                     └──────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Stack Final

| Camada | Tecnologia | Versão | Peso | Justificativa |
|--------|-----------|--------|------|---------------|
| **Frontend** | React + Vite | 18 + 5 | ~50KB gzip | SPA pura, build offline, assets com hash, roteamento client-side |
| **Linguagem** | TypeScript | 5.x | - | Tipagem, menos bugs, manutenção futura |
| **CSS** | Tailwind CSS | 3.x | ~10KB final | Utilitário, purgado em build, zero CDN |
| **Gráficos** | Recharts | 2.x | ~50KB | SVG declarativo, React nativo, reativo |
| **Ícones** | Lucide React | 0.x | tree-shaken | SVG como componente, apenas ícones usados no bundle |
| **State** | Zustand | 4.x | ~1KB | Leve, simples, sem boilerplate Redux |
| **HTTP** | Axios | 1.x | ~13KB | Interceptors, melhor DX que fetch nativo |
| **Toast** | Sonner | 1.x | ~3KB | Notificações toast leves |
| **Backend** | FastAPI | 0.111+ | - | Async nativo, OpenAPI auto, Pydantic v2 validação |
| **Server** | Uvicorn | 0.29+ | - | ASGI rápido, produção |
| **ORM** | SQLAlchemy 2.0 | 2.0+ | - | Async, maduro, PostgreSQL nativo |
| **Migrações** | Alembic | 1.13+ | - | Versionamento de schema, offline |
| **PDF** | WeasyPrint | 61+ | - | Zero browser, CSS Paged Media, HTML→PDF |
| **Gráficos PDF** | matplotlib | 3.8+ | - | PNG alta qualidade, 100% offline |
| **Auth** | python-jose | 3.x | - | JWT HS256, stateless |
| **Senhas** | passlib+bcrypt | 1.7+ | - | Cost factor 12, seguro |
| **Agendador** | APScheduler | 3.x | - | Backup diário, limpeza tokens |
| **DB Driver** | asyncpg | 0.29+ | - | Async PostgreSQL mais rápido |
| **Banco** | PostgreSQL | 16 | - | ACID, FTS, JSONB, replicação, cloud-ready |
| **Proxy** | Nginx | latest-alpine | - | Reverse proxy, static files, security headers |
| **Container** | Docker Compose | 3.9 | - | Multi-container, volumes, healthchecks |

### 2.3 Decisão Final Frontend: React + Vite (NÃO Next.js)

| Critério | React + Vite | Next.js |
|----------|:---:|:---:|
| Build 100% offline | ✅ | ✅ (standalone) |
| Bundle final leve | ✅ ~50KB | ❌ ~100KB+ |
| Sem Node.js no deploy | ✅ SP estática | ❌ precisa Node runtime |
| Roteamento SPA | ✅ React Router | ✅ file-based |
| Complexidade | ✅ Baixa | ❌ Média |
| SSR/SSG necessário | ❌ Não | ✅ Sim, mas inútil aqui |
| Curva de aprendizado | ✅ Baixa | ❌ Média |

**Decisão:** React + Vite. O sistema é 100% SPA interna, sem necessidade de SSR. Build gera pasta `dist/` com HTML+JS+CSS estáticos servidos pelo Nginx. Mais leve, mais simples, deploy mais fácil.

### 2.4 Decisão Final Backend: FastAPI (Python)

| Critério | FastAPI | NestJS (Node) |
|----------|:---:|:---:|
| Performance | ✅ Async nativo | ✅ Async |
| PDF server-side | ✅ WeasyPrint/ReportLab | ❌ Puppeteer (300MB+) ou jsPDF (limitado) |
| Gráficos server-side | ✅ matplotlib | ❌ Canvas/Sharp (frágil) |
| Validação | ✅ Pydantic v2 | ✅ class-validator |
| OpenAPI/Swagger | ✅ Automático | ✅ Decorators |
| Curva de aprendizado | ✅ Baixa | ❌ Média (decorators, modules) |
| Empacotamento offline | ✅ pip download | ✅ npm (mas node_modules pesado) |

**Decisão:** FastAPI. A geração de PDF corporativo de qualidade é crítica para o projeto. Python tem as melhores bibliotecas do mercado para isso (WeasyPrint, ReportLab, matplotlib). FastAPI é moderno, rápido e com validação excelente.

---

## 3. Estrutura de Pastas

```
sistema-ofs-mvp/
│
├── docker-compose.yml                    # Orquestração 3 serviços
├── docker-compose.override.yml           # Dev (hot-reload)
├── .env.example                          # Template variáveis
├── Makefile                              # Comandos: up, down, backup, restore
├── README.md                             # Deploy e operação
│
├── frontend/                             # React + Vite + TypeScript
│   ├── index.html
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts                    # Proxy /api → backend:8000
│   ├── tailwind.config.ts                # Cores corporativas, fonte Inter
│   ├── postcss.config.js
│   ├── public/
│   │   └── logo-sd.svg                   # Logo Security Dynamics
│   └── src/
│       ├── main.tsx                      # Entry point
│       ├── App.tsx                       # Router + Suspense
│       ├── index.css                     # Tailwind + @font-face Inter
│       │
│       ├── types/
│       │   ├── index.ts                  # User, Company, Contract, Target, OfcRecord
│       │   ├── api.ts                    # ApiResponse<T>, PaginatedResponse<T>
│       │   └── metrics.ts               # WeeklyMetrics, ChartData
│       │
│       ├── lib/
│       │   ├── api.ts                    # Axios instance + interceptors
│       │   └── utils.ts                  # cn(), formatDate, formatPercent
│       │
│       ├── stores/
│       │   └── authStore.ts              # user, token, login(), logout()
│       │
│       ├── hooks/
│       │   └── index.ts                  # useAuth, useDebounce
│       │
│       ├── components/
│       │   ├── ui/
│       │   │   ├── Button.tsx            # variant: primary|secondary|danger|ghost
│       │   │   ├── Input.tsx             # label + error + icon
│       │   │   ├── Select.tsx            # label + error + options
│       │   │   ├── DatePicker.tsx        # input[type=date] estilizado
│       │   │   ├── Modal.tsx             # overlay + ESC + 3 tamanhos
│       │   │   ├── Table.tsx             # <T> genérica, sort, loading, empty
│       │   │   ├── Pagination.tsx        # ellipsis, prev/next, page size
│       │   │   ├── Card.tsx              # title + subtitle + action
│       │   │   ├── Badge.tsx             # success|warning|danger|info|neutral
│       │   │   ├── Spinner.tsx           # 3 tamanhos
│       │   │   └── EmptyState.tsx        # ícone + mensagem + botão ação
│       │   ├── layout/
│       │   │   ├── AppShell.tsx          # Sidebar + Header + <Outlet/>
│       │   │   ├── Sidebar.tsx           # Nav links + admin section + mobile
│       │   │   ├── Header.tsx            # Logo + título + user dropdown
│       │   │   └── ProtectedRoute.tsx    # Auth guard + role check
│       │   └── charts/
│       │       ├── BarChartCard.tsx       # Recharts bar (wrapper)
│       │       ├── PieChartCard.tsx       # Recharts pie/donut
│       │       └── LineChartCard.tsx      # Recharts line
│       │
│       └── pages/
│           ├── LoginPage.tsx             # /login
│           ├── NovoOFCPage.tsx           # /OFS/novo — TELA PRINCIPAL DO MVP
│           ├── ListaOFCPage.tsx          # /OFS — Lista com filtros rápidos
│           ├── DetalheOFCPage.tsx        # /OFS/:id — Visualização completa
│           ├── EditarOFCPage.tsx         # /OFS/:id/editar — Edição
│           ├── ConsultaPage.tsx          # /consulta — Busca avançada
│           ├── MetricasPage.tsx          # /metricas — PAINEL PRINCIPAL DO MVP
│           ├── RelatoriosPage.tsx        # /relatorios — Gerar + histórico
│           ├── PerfilPage.tsx            # /perfil — Alterar senha
│           └── admin/
│               ├── UsuariosPage.tsx      # /admin/usuarios
│               ├── EmpresasPage.tsx      # /admin/empresas
│               ├── ContratosPage.tsx     # /admin/contratos
│               ├── MetasPage.tsx         # /admin/metas
│               ├── AuditoriaPage.tsx     # /admin/auditoria
│               └── BackupPage.tsx        # /admin/backup
│
├── backend/                              # FastAPI + Python 3.12
│   ├── Dockerfile                        # Multi-stage: pip download → install offline
│   ├── pyproject.toml                    # Dependências
│   ├── alembic.ini                       # Config Alembic
│   ├── alembic/
│   │   ├── env.py
│   │   └── versions/
│   │       ├── 001_initial_schema.py     # Todas as tabelas
│   │       └── 002_seed_data.py          # 15 empresas + admin
│   │
│   ├── app/
│   │   ├── main.py                       # FastAPI app, CORS, lifespan, routers
│   │   ├── config.py                     # Settings (env vars)
│   │   ├── database.py                   # Engine async, session factory
│   │   │
│   │   ├── models/                       # SQLAlchemy ORM
│   │   │   ├── user.py                   # User + UserRole enum
│   │   │   ├── company.py                # Company
│   │   │   ├── contract.py               # Contract
│   │   │   ├── target.py                 # Target (meta semanal)
│   │   │   ├── ofc_record.py             # OfcRecord + OfcEditLog
│   │   │   ├── audit_log.py              # AuditLog
│   │   │   ├── report.py                 # Report (PDF gerado)
│   │   │   └── backup.py                 # BackupLog
│   │   │
│   │   ├── schemas/                      # Pydantic v2
│   │   │   ├── auth.py                   # LoginRequest, TokenResponse
│   │   │   ├── user.py                   # UserCreate, UserUpdate, UserResponse
│   │   │   ├── company.py                # CompanyCreate, CompanyResponse
│   │   │   ├── contract.py               # ContractCreate, ContractResponse
│   │   │   ├── target.py                 # TargetCreate, TargetResponse
│   │   │   ├── ofc_record.py             # OfcCreate, OfcUpdate, OfcResponse
│   │   │   ├── metrics.py                # WeeklyMetricsResponse
│   │   │   ├── report.py                 # ReportGenerateRequest, ReportResponse
│   │   │   └── common.py                 # PaginatedResponse, ErrorResponse
│   │   │
│   │   ├── api/
│   │   │   ├── deps.py                   # get_db, get_current_user, require_role
│   │   │   ├── auth.py                   # POST /login, /refresh, /logout, GET /me
│   │   │   ├── users.py                  # CRUD /users
│   │   │   ├── companies.py              # CRUD /companies
│   │   │   ├── contracts.py              # CRUD /contracts
│   │   │   ├── targets.py                # CRUD /targets + GET /targets/current
│   │   │   ├── ofc_records.py            # CRUD /OFS-records + cancel
│   │   │   ├── consulta.py               # GET /consulta (filtros dinâmicos)
│   │   │   ├── metrics.py                # GET /metrics/weekly + /charts/*
│   │   │   ├── reports.py                # POST /reports/generate, GET /download
│   │   │   ├── audit.py                  # GET /audit (admin)
│   │   │   └── backup.py                 # POST /backup/manual, POST /restore
│   │   │
│   │   ├── services/                     # Lógica de negócio
│   │   │   ├── auth_service.py           # JWT, bcrypt, lockout
│   │   │   ├── user_service.py           # CRUD + validações
│   │   │   ├── company_service.py        # CRUD + seed
│   │   │   ├── contract_service.py       # CRUD
│   │   │   ├── target_service.py         # CRUD + busca meta vigente
│   │   │   ├── ofc_service.py            # Create, update, cancel, regras janela
│   │   │   ├── consulta_service.py       # Query builder dinâmico
│   │   │   ├── metrics_service.py        # Cálculo métricas semanais
│   │   │   ├── chart_service.py          # matplotlib → PNG (5 gráficos MVP)
│   │   │   ├── pdf_service.py            # Jinja2 + WeasyPrint
│   │   │   ├── audit_service.py          # Log + consulta
│   │   │   └── backup_service.py         # pg_dump / pg_restore
│   │   │
│   │   └── core/
│   │       ├── security.py               # Token, hash, verify
│   │       ├── permissions.py            # require_role(), data_scope()
│   │       ├── exceptions.py             # AppException handlers
│   │       └── scheduler.py              # APScheduler: backup 03:00
│   │
│   ├── templates/                        # Jinja2 HTML para PDF
│   │   ├── _base.html                    # Header/Footer corporativo + CSS
│   │   ├── individual_ofc.html           # PDF individual da OFS
│   │   └── weekly_metrics.html           # PDF MÉTRICAS DA SEMANA
│   │
│   └── static/
│       ├── fonts/
│       │   ├── Inter-Regular.woff2       # Fonte local
│       │   ├── Inter-SemiBold.woff2
│       │   └── Inter-Bold.woff2
│       └── logos/
│           └── security-dynamics.png     # Logo para PDF
│
└── nginx/
    ├── Dockerfile
    ├── nginx.conf                        # Reverse proxy + static + headers
    └── mime.types
```

---

## 4. Modelo do Banco de Dados (MVP)

### 4.1 Tabelas Essenciais (7 tabelas)

```sql
-- ============================================================
-- TABELA 1: companies (Empresas observadas)
-- ============================================================
CREATE TABLE companies (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    is_custom   BOOLEAN DEFAULT FALSE,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA 2: users (Usuários do sistema)
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(100) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(200) NOT NULL,
    email           VARCHAR(200),
    role            VARCHAR(20) NOT NULL CHECK (role IN ('observador','supervisor','gestor','admin')),
    company_id      INT REFERENCES companies(id),
    is_active       BOOLEAN DEFAULT TRUE,
    last_login      TIMESTAMPTZ,
    login_attempts  INT DEFAULT 0,
    locked_until    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_company ON users(company_id);

-- ============================================================
-- TABELA 3: contracts (Contratos)
-- ============================================================
CREATE TABLE contracts (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    company_id  INT NOT NULL REFERENCES companies(id),
    description TEXT,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_contracts_company ON contracts(company_id);

-- ============================================================
-- TABELA 4: targets (Metas semanais)
-- ============================================================
CREATE TABLE targets (
    id              SERIAL PRIMARY KEY,
    company_id      INT NOT NULL REFERENCES companies(id),
    contract_id     INT REFERENCES contracts(id),
    week_start      DATE NOT NULL,
    active_people   INT NOT NULL DEFAULT 1,
    weekly_target   INT NOT NULL DEFAULT 25,
    active_users    INT NOT NULL DEFAULT 1,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(company_id, contract_id, week_start)
);
CREATE INDEX idx_targets_week ON targets(company_id, week_start);

-- ============================================================
-- TABELA 5: ofc_records (Registros OFS/OFS — TABELA PRINCIPAL)
-- ============================================================
CREATE TABLE ofc_records (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequential_number   SERIAL,
    record_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    record_time         TIME NOT NULL DEFAULT CURRENT_TIME,
    generated_by        UUID NOT NULL REFERENCES users(id),
    observed_name       VARCHAR(200) NOT NULL,
    activity_observed   VARCHAR(300) NOT NULL,
    location_observed   VARCHAR(200) NOT NULL,
    company_id          INT REFERENCES companies(id),
    custom_company_name VARCHAR(150),
    shift               VARCHAR(50) NOT NULL,
    type                VARCHAR(20) NOT NULL CHECK (type IN ('Positivo/Seguro','Negativo/Inseguro')),
    behavior_observed   TEXT NOT NULL,
    complementary_obs   TEXT,
    status              VARCHAR(20) DEFAULT 'ativo' CHECK (status IN ('ativo','editado','cancelado')),
    cancel_reason       TEXT,
    is_deleted          BOOLEAN DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id),
    edit_count          INT DEFAULT 0,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Índices MVPs (essenciais)
CREATE INDEX idx_ofc_date       ON ofc_records(record_date);
CREATE INDEX idx_ofc_company    ON ofc_records(company_id);
CREATE INDEX idx_ofc_type       ON ofc_records(type);
CREATE INDEX idx_ofc_user       ON ofc_records(generated_by);
CREATE INDEX idx_ofc_status     ON ofc_records(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_metrics    ON ofc_records(company_id, record_date, type) WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_shift      ON ofc_records(shift);
-- Full-text search (português)
CREATE INDEX idx_ofc_fts        ON ofc_records USING GIN(to_tsvector('portuguese',
                                   coalesce(observed_name,'') || ' ' || 
                                   coalesce(behavior_observed,'') || ' ' || 
                                   coalesce(complementary_obs,'')));

-- ============================================================
-- TABELA 6: ofc_edit_log (Histórico de edições)
-- ============================================================
CREATE TABLE ofc_edit_log (
    id              BIGSERIAL PRIMARY KEY,
    ofc_record_id   UUID NOT NULL REFERENCES ofc_records(id),
    edited_by       UUID NOT NULL REFERENCES users(id),
    field_changed   VARCHAR(100) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_edit_log_ofc ON ofc_edit_log(ofc_record_id);

-- ============================================================
-- TABELA 7: audit_logs (Auditoria geral)
-- ============================================================
CREATE TABLE audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    timestamp   TIMESTAMPTZ DEFAULT NOW(),
    user_id     UUID REFERENCES users(id),
    username    VARCHAR(100),
    action      VARCHAR(50) NOT NULL,
    resource    VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    details     JSONB,
    ip_address  VARCHAR(45),
    severity    VARCHAR(20) DEFAULT 'INFO'
);
CREATE INDEX idx_audit_ts   ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id, timestamp DESC);
CREATE INDEX idx_audit_action ON audit_logs(action);

-- ============================================================
-- TABELA 8: reports (Relatórios PDF gerados)
-- ============================================================
CREATE TABLE reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type        VARCHAR(50) NOT NULL,
    title       VARCHAR(200),
    parameters  JSONB NOT NULL,
    file_path   VARCHAR(500),
    file_size   BIGINT,
    generated_by UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA 9: backups (Histórico de backups)
-- ============================================================
CREATE TABLE backups (
    id          SERIAL PRIMARY KEY,
    filename    VARCHAR(300) NOT NULL,
    file_path   VARCHAR(500) NOT NULL,
    size_bytes  BIGINT,
    type        VARCHAR(20) DEFAULT 'auto',
    status      VARCHAR(20) DEFAULT 'success',
    error_msg   TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA 10: revoked_tokens (Blacklist JWT)
-- ============================================================
CREATE TABLE revoked_tokens (
    id          SERIAL PRIMARY KEY,
    jti         VARCHAR(255) NOT NULL UNIQUE,
    user_id     UUID NOT NULL REFERENCES users(id),
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### 4.2 Seed Data

```sql
-- Empresas
INSERT INTO companies (name, is_custom) VALUES
    ('Security Dynamics', FALSE),
    ('Polo Norte', FALSE),
    ('G4S', FALSE),
    ('ERA', FALSE),
    ('Innovatec', FALSE),
    ('Conin', FALSE),
    ('FM', FALSE),
    ('Sodexo', FALSE),
    ('Engecom', FALSE),
    ('P&G', FALSE),
    ('Yusen', FALSE),
    ('Mainpower', FALSE),
    ('Aduana', FALSE),
    ('Prosegur', FALSE),
    ('Outros', TRUE);

-- Admin (senha: admin123 → bcrypt)
INSERT INTO users (id, username, password_hash, full_name, email, role, company_id) VALUES
    (gen_random_uuid(), 'admin', '$2b$12$LJ3m4ys3Lk0TSwHCpNqrIO8mXDZpJqKMGmF0MGZyPFBvfHaaVUwOe',
     'Administrador', 'admin@securitydynamics.com.br', 'admin', 1);

-- Meta padrão para Security Dynamics
INSERT INTO targets (company_id, week_start, active_people, weekly_target, active_users) VALUES
    (1, date_trunc('week', CURRENT_DATE)::date, 50, 5, 10);
```

---

## 5. Endpoints da API (MVP)

### 5.1 Auth — `/api/auth`

| Método | Path | Body/Params | Response |
|--------|------|-------------|----------|
| `POST` | `/login` | `{username, password}` | `{access_token, refresh_token, user}` |
| `POST` | `/refresh` | `{refresh_token}` | `{access_token, refresh_token}` |
| `POST` | `/logout` | `{refresh_token}` | `{success: true}` |
| `GET` | `/me` | — | `{user}` |
| `PUT` | `/change-password` | `{current, new, confirm}` | `{success: true}` |

### 5.2 Users — `/api/users` (Gestor/Admin)

| Método | Path | Query/Body | Response |
|--------|------|------------|----------|
| `GET` | `/` | `?company_id=&role=&is_active=&page=&page_size=` | `PaginatedResponse<User>` |
| `GET` | `/{id}` | — | `User` |
| `POST` | `/` | `UserCreate` | `User` (201) |
| `PUT` | `/{id}` | `UserUpdate` | `User` |
| `PATCH` | `/{id}/status` | `{is_active}` | `User` |

### 5.3 Companies — `/api/companies`

| Método | Path | Observação |
|--------|------|------------|
| `GET` | `/` | Lista ativas. Admin vê todas, outros veem lista para dropdown |
| `GET` | `/{id}` | Detalhe |
| `POST` | `/` | Admin only |
| `PUT` | `/{id}` | Admin only |
| `PATCH` | `/{id}/status` | Admin only |

### 5.4 Contracts — `/api/contracts` (Gestor/Admin)

| Método | Path | Query |
|--------|------|-------|
| `GET` | `/` | `?company_id=&is_active=` |
| `GET` | `/{id}` | — |
| `POST` | `/` | `ContractCreate` |
| `PUT` | `/{id}` | `ContractUpdate` |
| `PATCH` | `/{id}/status` | `{is_active}` |

### 5.5 Targets — `/api/targets` (Gestor/Admin)

| Método | Path | Query/Body |
|--------|------|------------|
| `GET` | `/` | `?company_id=&contract_id=&is_active=` |
| `GET` | `/{id}` | — |
| `POST` | `/` | `TargetCreate` |
| `PUT` | `/{id}` | `TargetUpdate` |
| `GET` | `/current` | `?company_id=&contract_id=` → meta vigente esta semana |

### 5.6 OFS Records — `/api/OFS-records` (CRUD PRINCIPAL)

| Método | Path | Descrição |
|--------|------|-----------|
| `POST` | `/` | Criar OFS. Campos automáticos: id, data, hora, generated_by |
| `GET` | `/` | Listar (visibilidade por perfil). `?page=&page_size=&type=&status=&start_date=&end_date=` |
| `GET` | `/{id}` | Detalhe + histórico de edições |
| `PUT` | `/{id}` | Editar (regras de janela por perfil) |
| `PATCH` | `/{id}/cancel` | Cancelar `{reason}` (Gestor/Admin) |

**POST /OFS-records — Body:**
```json
{
  "observed_name": "João Silva",
  "activity_observed": "Operação de empilhadeira",
  "location_observed": "Armazém B",
  "company_id": 1,
  "custom_company_name": null,
  "shift": "Diurno",
  "type": "Positivo/Seguro",
  "behavior_observed": "Uso correto de todos os EPIs",
  "complementary_obs": "Operador demonstrou atenção aos procedimentos"
}
```

### 5.7 Consulta — `/api/consulta`

| Método | Path | Query Params |
|--------|------|-------------|
| `GET` | `/` | `?start_date=&end_date=&company_id=&type=&shift=&location=&generated_by=&observed_name=&status=&page=&page_size=&order_by=&order_dir=` |

### 5.8 Metrics — `/api/metrics`

| Método | Path | Query Params | Retorno |
|--------|------|-------------|---------|
| `GET` | `/weekly` | `?week_start=&company_id=&contract_id=` | `WeeklyMetrics` (10 indicadores + status) |
| `GET` | `/charts/programmed-vs-realized` | `?week_start=&company_id=` | `{chart_data}` |
| `GET` | `/charts/positive-vs-negative` | `?week_start=&company_id=` | `{chart_data}` |
| `GET` | `/charts/by-company` | `?week_start=` | `{chart_data}` |
| `GET` | `/charts/by-user` | `?week_start=&company_id=` | `{chart_data}` |
| `GET` | `/charts/weekly-evolution` | `?weeks=8&company_id=` | `{chart_data}` |

### 5.9 Reports — `/api/reports`

| Método | Path | Body/Params |
|--------|------|-------------|
| `POST` | `/generate` | `{type: "individual"\|"weekly", ofc_id, week_start, company_id}` |
| `GET` | `/` | Histórico de relatórios gerados |
| `GET` | `/{id}/download` | Download do PDF (StreamingResponse) |

### 5.10 Audit — `/api/audit` (Admin)

| Método | Path | Query |
|--------|------|-------|
| `GET` | `/` | `?user_id=&action=&resource=&start_date=&end_date=&page=&page_size=` |

### 5.11 Backup — `/api/backup` (Admin)

| Método | Path | Descrição |
|--------|------|-----------|
| `GET` | `/status` | Status do último backup |
| `GET` | `/` | Histórico |
| `POST` | `/manual` | Disparar backup agora |
| `POST` | `/{id}/restore` | Restaurar `{confirm: true}` |

---

## 6. Telas do MVP (12 Telas)

### 6.1 Rotas e Perfis

| Rota | Tela | Observador | Supervisor | Gestor | Admin |
|------|------|:---:|:---:|:---:|:---:|
| `/login` | Login | ✅ | ✅ | ✅ | ✅ |
| `/OFS/novo` | Novo OFS | ✅ | ✅ | ✅ | ✅ |
| `/OFS` | Lista OFCs | ✅ | ✅ | ✅ | ✅ |
| `/OFS/:id` | Detalhe OFS | ✅ | ✅ | ✅ | ✅ |
| `/OFS/:id/editar` | Editar OFS | Seu | Empresa | ✅ | ✅ |
| `/consulta` | Consulta | ✅ | ✅ | ✅ | ✅ |
| `/metricas` | Métricas + Gráficos | ❌ | Sua empresa | ✅ | ✅ |
| `/relatorios` | Relatórios PDF | ❌ | ❌ | ✅ | ✅ |
| `/perfil` | Alterar Senha | ✅ | ✅ | ✅ | ✅ |
| `/admin/usuarios` | Usuários | ❌ | ❌ | Empresa | ✅ |
| `/admin/empresas` | Empresas | ❌ | ❌ | ❌ | ✅ |
| `/admin/contratos` | Contratos | ❌ | ❌ | Empresa | ✅ |
| `/admin/metas` | Metas | ❌ | ❌ | Empresa | ✅ |
| `/admin/auditoria` | Auditoria | ❌ | ❌ | ❌ | ✅ |
| `/admin/backup` | Backup | ❌ | ❌ | ❌ | ✅ |

### 6.2 Descrição das Telas Críticas

#### Tela 1 — Login (`/login`)

```
┌──────────────────────────────────────┐
│                                      │
│        [LOGO Security Dynamics]      │
│                                      │
│     Sistema de Feedback              │
│     Comportamental OFS/OFS           │
│                                      │
│  ┌──────────────────────────────┐    │
│  │  👤 Usuário                  │    │
│  └──────────────────────────────┘    │
│  ┌──────────────────────────────┐    │
│  │  🔒 Senha                    │    │
│  └──────────────────────────────┘    │
│                                      │
│  [─────────── ENTRAR ───────────]    │
│                                      │
│  (msg erro: credenciais inválidas)   │
│                                      │
└──────────────────────────────────────┘
```

#### Tela 2 — Novo OFS (`/OFS/novo`) — TELA PRINCIPAL DO MVP

```
┌──────────────────────────────────────────────────────────────┐
│  ← VOLTAR                          NOVO REGISTRO OFS/OFS     │
│                                                               │
│  ┌─────────────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │ ID: AUTO        │  │ Data:    │  │ Hora: AUTO           │ │
│  │ (gerado ao salvar)│  │ 13/05/26│  │ 14:30               │ │
│  └─────────────────┘  └──────────┘  └──────────────────────┘ │
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐│
│  │ Gerado por: João Silva (joao.silva) | Security Dynamics  ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  ────── DADOS DA OBSERVAÇÃO ──────                            │
│                                                               │
│  Nome do Observado *                                          │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                                                          ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  Atividade Observada *                                        │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                                                          ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  Local Observado *                                            │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                                                          ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  Empresa Observada *          Turno *        Tipo *           │
│  ┌────────────────────┐ ┌──────────────┐ ┌──────────────────┐│
│  │ Security Dynamics ▾│ │ Diurno     ▾ │ │ Positivo/Seguro ▾││
│  └────────────────────┘ └──────────────┘ └──────────────────┘│
│                                                               │
│  (Se Empresa = "Outros", aparece:)                            │
│  Nome da Empresa *                                            │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                                                          ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  Comportamento Observado *                                    │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                                                          ││
│  │                                                          ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  Observação Complementar                                      │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                                                          ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌──────────────┐              ┌───────────────────────────┐  │
│  │  💾 SALVAR   │              │  CANCELAR                 │  │
│  └──────────────┘              └───────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

#### Tela 3 — Consulta (`/consulta`)

```
┌──────────────────────────────────────────────────────────────┐
│  CONSULTA AVANÇADA                                           │
│                                                               │
│  FILTROS:                                                     │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │ Data Ini.  │ │ Data Fim   │ │ Empresa  ▾ │ │ Turno   ▾ │ │
│  └────────────┘ └────────────┘ └────────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │ Tipo     ▾ │ │ Status   ▾ │ │ Usuário  ▾ │ │ Local     │ │
│  └────────────┘ └────────────┘ └────────────┘ └───────────┘ │
│                                                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────────┐  │
│  │ 🔍 BUSCAR  │  │ 🗑 LIMPAR  │  │ Resultados: 47 OFCs   │  │
│  └────────────┘  └────────────┘  └────────────────────────┘  │
│                                                               │
│  ┌──────┬──────────┬──────────┬──────────┬──────────┬──────┐ │
│  │Nº OFS│ Data     │Observado │Empresa   │Tipo      │Status│ │
│  ├──────┼──────────┼──────────┼──────────┼──────────┼──────┤ │
│  │ 1523 │13/05/2026│João Silva│Sec. Dyn. │Positivo  │Ativo │ │
│  │ 1522 │13/05/2026│Maria Souza│G4S     │Negativo  │Ativo │ │
│  │ 1521 │12/05/2026│Pedro Lima│ERA      │Positivo  │Editad│ │
│  │ ...  │...       │...       │...       │...       │...   │ │
│  └──────┴──────────┴──────────┴──────────┴──────────┴──────┘ │
│                                                               │
│  ◀ Página 1 de 5 ▶                                           │
└──────────────────────────────────────────────────────────────┘
```

#### Tela 4 — Métricas da Semana (`/metricas`) — PAINEL PRINCIPAL DO MVP

```
┌──────────────────────────────────────────────────────────────┐
│  MÉTRICAS DA SEMANA                                          │
│                                                               │
│  ◀ Semana Anterior   13/05/2026 — 19/05/2026   Próx. Semana ▶│
│                                                               │
│  Empresa: [Security Dynamics ▾]  Contrato: [Todos ▾]         │
│                                                               │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │  ADERÊNCIA   │ │  % SEGURO    │ │   STATUS             │  │
│  │              │ │              │ │                      │  │
│  │    86.0%     │ │   82.7%      │ │   🟡 ATENÇÃO         │  │
│  │              │ │              │ │                      │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │ Pessoas  │ │ OFS      │ │ OFS      │ │ Usuários │        │
│  │ Ativas   │ │Programada│ │Realizada │ │ Ativos   │        │
│  │   150    │ │   450    │ │   387    │ │   28     │        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │Positivas │ │Negativas │ │Média por │ │% Desvio  │        │
│  │   320    │ │   67     │ │ Usuário  │ │  17.3%   │        │
│  │          │ │          │ │   13.8   │ │          │        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
│                                                               │
│  ═══════════════ GRÁFICOS ═══════════════                     │
│                                                               │
│  ┌─────────────────────────┐ ┌─────────────────────────┐     │
│  │ Programado x Realizado  │ │ Positivo x Negativo     │     │
│  │      [BARRAS]           │ │      [DONUT]            │     │
│  └─────────────────────────┘ └─────────────────────────┘     │
│                                                               │
│  ┌─────────────────────────┐ ┌─────────────────────────┐     │
│  │ OFS por Empresa         │ │ OFS por Usuário         │     │
│  │    [BARRAS HORIZ.]      │ │    [BARRAS]             │     │
│  └─────────────────────────┘ └─────────────────────────┘     │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ Evolução Semanal (últimas 8 semanas)                  │   │
│  │    [LINHA COM META 100% E ALERTA 80%]                │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

#### Tela 5 — Relatórios (`/relatorios`)

```
┌──────────────────────────────────────────────────────────────┐
│  RELATÓRIOS PDF                                              │
│                                                               │
│  ┌─────────────────────────┐ ┌──────────────────────────────┐│
│  │ 📄 PDF Individual       │ │ 📊 PDF Semanal               ││
│  │                         │ │                              ││
│  │ Registro único de OFS   │ │ Métricas completas da semana ││
│  │ com todos os campos     │ │ com indicadores e gráficos   ││
│  │                         │ │                              ││
│  │ Nº OFS: [__________]    │ │ Semana: [13/05/2026 ▾]      ││
│  │                         │ │ Empresa: [Security Dyn. ▾]  ││
│  │ [ GERAR PDF ]           │ │ [ GERAR PDF ]                ││
│  └─────────────────────────┘ └──────────────────────────────┘│
│                                                               │
│  ═══════════ HISTÓRICO ═══════════                            │
│                                                               │
│  ┌──────────────────────────────┬──────────┬────────┬──────┐ │
│  │ Relatório                    │Gerado em │Por     │ Down.│ │
│  ├──────────────────────────────┼──────────┼────────┼──────┤ │
│  │OFCS_1523_JoaoSilva_13052026  │13/05 14:30│Admin  │ [⬇] │ │
│  │METRICAS_SEMANAL_13052026     │13/05 14:31│Admin  │ [⬇] │ │
│  └──────────────────────────────┴──────────┴────────┴──────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. Fluxo do Usuário

### 7.1 Fluxo Principal (Operador/Observador)

```
                    ┌─────────┐
                    │  LOGIN  │
                    └────┬────┘
                         │
                         ▼
              ┌────────────────────┐
              │ TELA: NOVO OFS/OFS │  ← Tela padrão após login
              │ (formulário)       │     (operador vai direto registrar)
              └────────┬───────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Salvar → │ │ Cancelar │ │ Sidebar  │
   │ Sucesso  │ │ (voltar) │ │ navega   │
   └──────────┘ └──────────┘ └────┬─────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
             ┌──────────┐  ┌──────────┐  ┌──────────┐
             │ Meus OFCs│  │ Consulta │  │ Perfil   │
             │ (lista)  │  │ (buscar) │  │ (senha)  │
             └────┬─────┘  └────┬─────┘  └──────────┘
                  │             │
                  ▼             ▼
           ┌──────────┐  ┌──────────┐
           │ Detalhe  │  │ Detalhe  │
           │ do OFS   │  │ do OFS   │
           └──────────┘  └──────────┘
```

### 7.2 Fluxo do Gestor/Admin

```
┌─────────┐
│  LOGIN  │
└────┬────┘
     │
     ▼
┌────────────────────┐
│  Métricas da Semana│  ← Tela padrão para Gestor
│  (dashboard)       │
└────────┬───────────┘
         │
  ┌──────┼──────┬──────────────┐
  ▼      ▼      ▼              ▼
┌────┐ ┌────┐ ┌──────────┐ ┌──────────┐
│OFS │ │Cons│ │Relatórios│ │  Admin   │
│Novo│ │ulta│ │   PDF    │ │ (gestão) │
└────┘ └────┘ └──────────┘ └──────────┘
```

---

## 8. Fluxo Administrativo

### 8.1 Setup Inicial do Sistema

```
1. Deploy Docker → Sistema no ar
2. Login como admin / admin123
3. Alterar senha do admin (obrigatório)
4. Cadastrar empresas adicionais (se necessário)
5. Criar usuários (Observadores, Supervisores, Gestores)
6. Criar contratos (vincular a empresas)
7. Criar metas (targets) para a semana atual:
   - Pessoas ativas
   - Meta semanal por pessoa
   - Usuários ativos
8. Sistema operacional → usuários começam a registrar OFCs
```

### 8.2 Rotina Semanal do Gestor

```
1. Segunda-feira: Verificar metas da semana (targets)
2. Diariamente: Acompanhar OFCs registradas vs programadas
3. Sexta-feira: Gerar PDF MÉTRICAS DA SEMANA
4. Reunião: Apresentar indicadores
5. Ajustar metas para próxima semana se necessário
```

### 8.3 Rotina do Admin

```
1. Diário: Verificar status do backup
2. Semanal: Revisar logs de auditoria
3. Mensal: Testar restore de backup
4. Sob demanda: Criar/desativar usuários, ajustar permissões
```

---

## 9. Regras de Negócio (MVP)

### 9.1 Geração de OFS

```
✓ ID: UUID gerado pelo backend (gen_random_uuid)
✓ Nº OFS: SERIAL do banco (sequencial, visível)
✓ Data: CURRENT_DATE do servidor
✓ Hora: CURRENT_TIME do servidor
✓ Gerado por: current_user (id, nome, login, empresa, perfil)
✓ Empresa padrão: a do usuário logado (editável)
✓ Se empresa = "Outros" (id=15): campo custom_company_name OBRIGATÓRIO
✓ Tipo: apenas "Positivo/Seguro" ou "Negativo/Inseguro"
✓ Status inicial: "ativo"
✓ Todos os campos de texto: trim(), mínimo 3 caracteres (nome) e 5 (comportamento)
✓ Não permitir data futura
```

### 9.2 Edição de OFS

```
✓ Observador: edita apenas seus registros, até 24h da criação
✓ Supervisor: edita registros da sua empresa, até 48h
✓ Gestor/Admin: edita qualquer registro, sem limite de tempo
✓ Cada campo alterado → registro em ofc_edit_log (campo, old_value, new_value)
✓ Status muda para "editado" (mantém editado mesmo após múltiplas edições)
✓ edit_count incrementado
✓ Audit log: action="UPDATE", details={campos alterados}
✓ Optimistic locking: verificar updated_at antes de salvar
  → Se outro usuário editou, retornar 409 CONFLICT
```

### 9.3 Cancelamento de OFS

```
✓ Apenas Gestor e Admin
✓ Soft delete: is_deleted = TRUE
✓ deleted_at = NOW()
✓ deleted_by = current_user.id
✓ cancel_reason obrigatório
✓ Status = "cancelado"
✓ Cancelados NÃO aparecem em métricas
✓ Cancelados NÃO aparecem em consultas (exceto filtro status=cancelado)
✓ Audit log: action="CANCEL", details={reason}
```

### 9.4 Métricas da Semana

```
✓ Busca target vigente: targets WHERE company_id = X AND week_start <= hoje AND is_active = TRUE
✓ OFS Programadas = active_people × weekly_target
✓ OFS Realizadas = COUNT(ofc_records) WHERE record_date BETWEEN week_start AND week_end
                    AND company_id = X AND is_deleted = FALSE AND status != 'cancelado'
✓ Aderência % = (Realizadas ÷ Programadas) × 100
✓ Positivas = COUNT WHERE type = 'Positivo/Seguro'
✓ Negativas = COUNT WHERE type = 'Negativo/Inseguro'
✓ % Seguro = (Positivas ÷ Realizadas) × 100
✓ % Desvio = (Negativas ÷ Realizadas) × 100
✓ Usuários Ativos = COUNT(DISTINCT generated_by)
✓ Média OFS/Usuário = Realizadas ÷ Usuários Ativos

STATUS:
  ≥ 100% → OK (verde)
  80-99% → ATENÇÃO (amarelo)
  < 80%  → ALERTA (vermelho)
```

---

## 10. Estratégia de PDF (MVP)

### 10.1 PDF Individual da OFS

```
Template: individual_ofc.html
Acionado por: POST /api/reports/generate {type: "individual", ofc_id: "uuid"}

Pipeline:
1. Busca ofc_record + ofc_edit_log + user info
2. Renderiza Jinja2 template com dados
3. WeasyPrint converte HTML → PDF
4. Salva em /app/reports/
5. Registra em reports table
6. Retorna URL de download

Layout:
- Cabeçalho: logo SD + "REGISTRO DE OFS/OFS"
- Nº OFS em destaque
- Bloco "DADOS GERAIS": data, hora, gerado por, empresa
- Bloco "DADOS DA OBSERVAÇÃO": observado, atividade, local, turno, tipo
- Bloco "COMPORTAMENTO OBSERVADO": texto completo
- Bloco "OBSERVAÇÃO COMPLEMENTAR": texto (se houver)
- Status com badge colorido
- Se editado: tabela de histórico de edições
- Rodapé: data/hora geração, página X/Y, "Documento gerado automaticamente"
```

### 10.2 PDF MÉTRICAS DA SEMANA

```
Template: weekly_metrics.html
Acionado por: POST /api/reports/generate {type: "weekly", week_start: "2026-05-11", company_id: 1}

Pipeline:
1. Chama metrics_service.calculate_weekly_metrics()
2. Chama chart_service para gerar 5 PNGs (salvos em temp):
   → programado_vs_realizado.png
   → positivo_vs_negativo.png
   → ofc_por_empresa.png
   → ofc_por_usuario.png
   → evolucao_semanal.png
3. Converte PNGs para base64
4. Renderiza Jinja2 template com métricas + imagens
5. WeasyPrint HTML → PDF
6. Limpa PNGs temporários
7. Salva PDF, registra, retorna download

Layout (2-3 páginas):
- PÁGINA 1:
  → Cabeçalho: "RELATÓRIO SEMANAL DE MÉTRICAS"
  → Subtítulo: semana, empresa, gerado por, data
  → Tabela de indicadores (10 linhas, status colorido)
  → Gráfico: Programado x Realizado
  → Gráfico: Positivo x Negativo
- PÁGINA 2:
  → Gráfico: OFS por Empresa
  → Gráfico: OFS por Usuário
  → Gráfico: Evolução Semanal (últimas 8 semanas)
- PÁGINA 3 (se necessário):
  → Continuação dos gráficos
  → Rodapé em todas as páginas
```

### 10.3 Identidade Visual nos PDFs

```css
/* Cores */
:root {
  --brand-red:    #CC0000;
  --brand-black:  #1A1A1A;
  --brand-gray:   #F5F5F5;
  --brand-white:  #FFFFFF;
  --success:      #22C55E;
  --warning:      #EAB308;
  --danger:       #EF4444;
}

/* @page */
@page {
  size: A4;
  margin: 20mm 20mm 25mm 20mm;
  @top-center {
    content: element(pageHeader);
  }
  @bottom-center {
    content: element(pageFooter);
  }
}

/* Header */
#pageHeader {
  display: flex;
  align-items: center;
  border-bottom: 2px solid var(--brand-red);
  padding-bottom: 5mm;
}
#pageHeader img { height: 20mm; }
#pageHeader .title { 
  font-family: 'Inter', sans-serif;
  font-weight: bold;
  font-size: 12pt;
  color: var(--brand-black);
  margin-left: auto;
}

/* Footer */
#pageFooter {
  border-top: 1px solid var(--brand-red);
  padding-top: 3mm;
  font-size: 8pt;
  color: #666;
  text-align: center;
}
```

---

## 11. Estratégia de Gráficos

### 11.1 Gráficos no Frontend (Recharts)

Usados na tela `/metricas`. Dados vêm dos endpoints `/api/metrics/charts/*`.

| Gráfico | Tipo Recharts | Endpoint |
|---------|:---:|------|
| Programado x Realizado | `<BarChart>` lado a lado | `/charts/programmed-vs-realized` |
| Positivo x Negativo | `<PieChart>` donut | `/charts/positive-vs-negative` |
| OFS por Empresa | `<BarChart>` horizontal | `/charts/by-company` |
| OFS por Usuário | `<BarChart>` vertical | `/charts/by-user` |
| Evolução Semanal | `<LineChart>` com linhas de referência | `/charts/weekly-evolution` |

### 11.2 Gráficos nos PDFs (matplotlib)

Os mesmos 5 gráficos são gerados server-side em PNG para embedar nos PDFs.

```python
# chart_service.py — estrutura de cada gráfico

def programado_vs_realizado(programmed, realized) -> bytes:
    fig, ax = plt.subplots(figsize=(8, 4))
    bars = ax.bar(['Programado', 'Realizado'], [programmed, realized],
                  color=['#3498db', '#f39c12'])
    ax.set_ylabel('Quantidade de OFCs')
    # Anotar valores no topo das barras
    for bar, val in zip(bars, [programmed, realized]):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 3,
                str(val), ha='center', fontweight='bold')
    return _fig_to_bytes(fig)

def positivo_vs_negativo(positive, negative) -> bytes:
    fig, ax = plt.subplots(figsize=(6, 6))
    ax.pie([positive, negative],
           labels=['Positivo/Seguro', 'Negativo/Inseguro'],
           colors=['#2ecc71', '#e74c3c'],
           autopct='%1.1f%%', startangle=90,
           wedgeprops=dict(width=0.4))  # donut
    return _fig_to_bytes(fig)
```

---

## 12. Estratégia de Backup (MVP)

### 12.1 Implementação

```python
# core/scheduler.py
from apscheduler.schedulers.asyncio import AsyncIOScheduler

scheduler = AsyncIOScheduler()

@scheduler.scheduled_job('cron', hour=3, minute=0)
async def daily_backup():
    """Backup diário automático às 03:00 AM."""
    filename = f"backup_{datetime.now():%Y%m%d_%H%M%S}.dump"
    filepath = f"/backups/{filename}"
    
    # pg_dump
    cmd = f"pg_dump -h {DB_HOST} -U {DB_USER} -d {DB_NAME} -Fc -f {filepath}"
    result = subprocess.run(cmd, shell=True, capture_output=True)
    
    if result.returncode == 0:
        size = os.path.getsize(filepath)
        # Registrar no banco
        async with async_session() as db:
            db.add(BackupLog(filename=filename, file_path=filepath,
                   size_bytes=size, type='auto', status='success'))
            await db.commit()
        
        # Rotação: manter últimos 30
        await rotate_backups(keep=30)
    else:
        logger.error(f"Backup failed: {result.stderr}")

# Rotação
async def rotate_backups(keep=30):
    backups = sorted(Path("/backups").glob("backup_*.dump"))
    for old in backups[:-keep]:
        old.unlink()
```

### 12.2 Política

| Item | Configuração |
|------|-------------|
| Frequência | Diário, 03:00 AM |
| Formato | pg_dump custom (comprimido) |
| Retenção | 30 backups mais recentes |
| Local | Volume Docker `./backups/` |
| Verificação | `pg_restore --list` após dump |
| Restauração | Admin via `/admin/backup` → seleciona arquivo → confirma |

### 12.3 Restauração Simplificada

```bash
# Manual (servidor)
docker compose exec backend pg_restore -h db -U ofs_user -d ofs_db \
  --clean --if-exists /backups/backup_20260513_030000.dump
```

---

## 13. Plano de Desenvolvimento por Etapas

### Semana 1-2: Fundação

```
BACKEND:
☐ Estrutura de pastas (backend/app/models, schemas, api, services, core)
☐ config.py com variáveis de ambiente
☐ database.py (async engine + session)
☐ Modelos SQLAlchemy: User, Company, Contract, Target, OfcRecord, 
  OfcEditLog, AuditLog, Report, BackupLog, RevokedToken
☐ Alembic init + migration inicial (todas as tabelas)
☐ Seed migration (15 empresas + admin)
☐ Dockerfile multi-stage
☐ docker-compose.yml (nginx + backend + db)

FRONTEND:
☐ Vite + React + TypeScript setup
☐ Tailwind config (cores corporativas)
☐ Estrutura de pastas
☐ Componentes UI base: Button, Input, Select, Spinner
☐ Layout: AppShell, Sidebar vazio, Header
☐ Roteamento base com ProtectedRoute
☐ Zustand authStore
☐ Axios instance + interceptors
☐ Font Inter local (@font-face)
```

### Semana 3: Autenticação

```
BACKEND:
☐ POST /api/auth/login (JWT access + refresh)
☐ POST /api/auth/refresh
☐ POST /api/auth/logout (revoke token)
☐ GET /api/auth/me
☐ PUT /api/auth/change-password
☐ Security: bcrypt, JWT encode/decode, lockout 5 tentativas
☐ RBAC dependencies: get_current_user, require_role
☐ Audit middleware

FRONTEND:
☐ LoginPage (/login) com validação
☐ Integração com authStore
☐ ProtectedRoute com verificação de role
☐ Header com nome do usuário + logout
☐ Sidebar com links condicionais por perfil
```

### Semana 4-5: CRUD OFS/OFS (CORAÇÃO DO MVP)

```
BACKEND:
☐ POST /api/OFS-records (criar) com todas as validações
☐ GET /api/OFS-records (listar com visibilidade por perfil)
☐ GET /api/OFS-records/{id} (detalhe + histórico de edições)
☐ PUT /api/OFS-records/{id} (editar com regras de janela)
☐ PATCH /api/OFS-records/{id}/cancel (soft delete)
☐ ofc_service.py com todas as regras de negócio
☐ Audit logging para todas as operações

FRONTEND:
☐ NovoOFCPage: formulário completo com dropdown dinâmico de empresas
☐ Regra "Outros": campo texto condicional
☐ ListaOFCPage: tabela com paginação, filtros rápidos
☐ DetalheOFCPage: visualização completa + badge status
☐ EditarOFCPage: formulário pré-preenchido
☐ Validação de formulários antes do submit
☐ Toast de sucesso/erro
```

### Semana 6: Cadastros Básicos

```
BACKEND:
☐ CRUD /api/users (Gestor/Admin)
☐ CRUD /api/companies (Admin)
☐ CRUD /api/contracts (Gestor/Admin)
☐ CRUD /api/targets (Gestor/Admin)
☐ GET /api/targets/current

FRONTEND:
☐ UsuariosPage: tabela + modal criar/editar
☐ EmpresasPage: tabela + modal criar/editar
☐ ContratosPage: tabela + modal criar/editar
☐ MetasPage: tabela + modal criar/editar
☐ Seletores de empresa/contrato reutilizáveis
```

### Semana 7-8: Consulta e Métricas

```
BACKEND:
☐ GET /api/consulta (query builder dinâmico com todos os filtros)
☐ Full-text search (tsvector português)
☐ GET /api/metrics/weekly (cálculo completo, 10 indicadores, status)
☐ GET /api/metrics/charts/programmed-vs-realized
☐ GET /api/metrics/charts/positive-vs-negative
☐ GET /api/metrics/charts/by-company
☐ GET /api/metrics/charts/by-user
☐ GET /api/metrics/charts/weekly-evolution

FRONTEND:
☐ ConsultaPage: painel de filtros + tabela de resultados
☐ MetricasPage: cards de indicadores + status colorido
☐ Seletor de semana (setas navegação)
☐ Seletor de empresa/contrato
☐ Gráficos Recharts integrados (5 gráficos)
```

### Semana 9-10: PDFs e Relatórios

```
BACKEND:
☐ chart_service.py: 5 gráficos matplotlib → PNG
☐ Jinja2 templates: _base.html, individual_ofc.html, weekly_metrics.html
☐ pdf_service.py: render Jinja2 → WeasyPrint → PDF bytes
☐ POST /api/reports/generate
☐ GET /api/reports/{id}/download
☐ GET /api/reports (histórico)

FRONTEND:
☐ RelatoriosPage: cards PDF Individual e PDF Semanal
☐ Seletor de OFS (para PDF individual)
☐ Seletor de semana/empresa (para PDF semanal)
☐ Histórico de relatórios com download
☐ Loading state durante geração do PDF
```

### Semana 11: Admin, Backup e Polimentos

```
BACKEND:
☐ GET /api/audit (consulta de logs, Admin)
☐ APScheduler: backup diário 03:00
☐ POST /api/backup/manual
☐ GET /api/backup/status
☐ POST /api/backup/{id}/restore
☐ Limpeza de tokens expirados (scheduler)

FRONTEND:
☐ AuditoriaPage: tabela de logs com filtros
☐ BackupPage: status, lista de backups, botão manual, botão restore
☐ PerfilPage: alterar senha
☐ Empty states para todas as listas
☐ Error boundaries
☐ Testes manuais de fluxo completo
```

### Semana 12: Testes e Deploy

```
☐ Teste de fluxo completo: login → cadastros → registro OFS → consulta → métricas → PDF
☐ Teste de regras de negócio: janela de edição, permissões, cancelamento
☐ Teste de backup e restore
☐ Ajustes de CSS/layout para tablet e mobile
☐ Documentação de deploy (README.md)
☐ Build de produção: docker compose build
☐ Deploy em servidor de teste
☐ Correções finais
```

---

## 14. Critérios de Aceite

### 14.1 Login e Autenticação

- [ ] Usuário faz login com username e senha
- [ ] Token JWT gerado com expiração de 15 minutos
- [ ] Refresh token funciona para renovar sem novo login
- [ ] Logout revoga refresh token
- [ ] 5 tentativas falhas bloqueiam usuário por 30 minutos
- [ ] Senha armazenada como bcrypt (nunca plain text)
- [ ] Alterar senha obriga senha atual + nova + confirmação

### 14.2 Registro OFS/OFS

- [ ] Formulário exibe ID, data e hora automáticos (não editáveis)
- [ ] Usuário logado aparece como "Gerado por" automaticamente
- [ ] Dropdown de empresas contém as 15 empresas
- [ ] Selecionar "Outros" exibe campo de nome obrigatório
- [ ] Tipo validado: apenas "Positivo/Seguro" ou "Negativo/Inseguro"
- [ ] Registro salvo com status "ativo"
- [ ] Número sequencial gerado automaticamente
- [ ] Audit log registrado (CREATE)
- [ ] Toast de confirmação exibido
- [ ] Registro aparece na lista do usuário

### 14.3 Consulta

- [ ] Filtro por período (data inicial e final) funciona
- [ ] Filtro por empresa funciona
- [ ] Filtro por tipo funciona
- [ ] Filtro por turno funciona
- [ ] Filtro por status funciona
- [ ] Filtro por usuário gerador funciona
- [ ] Combinação de filtros funciona (AND lógico)
- [ ] Resultados paginados
- [ ] Clicar em um resultado abre o detalhe

### 14.4 Edição e Cancelamento

- [ ] Observador edita seu OFS em até 24h → SUCESSO
- [ ] Observador tenta editar OFS de outro → BLOQUEADO (403)
- [ ] Observador tenta editar após 24h → BLOQUEADO (409, janela expirada)
- [ ] Supervisor edita OFS da empresa em até 48h → SUCESSO
- [ ] Supervisor edita OFS de outra empresa → BLOQUEADO (403)
- [ ] Gestor/Admin edita qualquer OFS → SUCESSO
- [ ] Histórico de edições registrado (ofc_edit_log)
- [ ] Cancelamento apenas por Gestor/Admin → SUCESSO
- [ ] Cancelamento exige motivo obrigatório
- [ ] OFS cancelada não aparece em métricas

### 14.5 Métricas da Semana

- [ ] 10 indicadores calculados corretamente
- [ ] OFS Programadas = Pessoas Ativas × Meta Semanal
- [ ] Aderência % = Realizadas ÷ Programadas × 100
- [ ] Status OK (verde) quando aderência >= 100%
- [ ] Status ATENÇÃO (amarelo) quando aderência entre 80% e 99%
- [ ] Status ALERTA (vermelho) quando aderência < 80%
- [ ] Filtro por empresa funciona
- [ ] Navegação entre semanas funciona (setas)

### 14.6 Gráficos

- [ ] Programado x Realizado exibido como barras lado a lado
- [ ] Positivo x Negativo exibido como donut
- [ ] OFS por Empresa exibido como barras horizontais
- [ ] OFS por Usuário exibido como barras
- [ ] Evolução Semanal exibida como linha com referências (100% e 80%)

### 14.7 PDFs

- [ ] PDF Individual: A4, logo SD, todos os campos, status, rodapé
- [ ] PDF Semanal: A4, logo SD, tabela de indicadores, 5 gráficos, rodapé
- [ ] Cores corporativas aplicadas (vermelho, preto, cinza, branco)
- [ ] Rodapé com data/hora e "Documento gerado automaticamente"
- [ ] Download funciona via API autenticada

### 14.8 Backup

- [ ] Backup automático diário executado às 03:00
- [ ] Arquivo .dump gerado no volume ./backups/
- [ ] Status visível na tela admin
- [ ] Backup manual funciona
- [ ] Restauração funciona (testar em ambiente isolado)
- [ ] Rotação mantém apenas 30 backups

### 14.9 Segurança e Auditoria

- [ ] Todas as ações registradas em audit_logs (CREATE, UPDATE, CANCEL, LOGIN)
- [ ] Logs visíveis apenas para Admin
- [ ] Tentativas de acesso não autorizado registradas
- [ ] Nenhum dado sensível em logs (senhas redacted)
- [ ] .env nunca commitado

### 14.10 Robustez

- [ ] Sistema funciona 100% offline (sem internet)
- [ ] Fontes e ícones carregam localmente
- [ ] Nenhum erro de CORS ou CDN
- [ ] Docker compose up → sistema funcional em < 2 minutos
- [ ] Banco de dados persiste entre restarts (volume)

---

**Documento gerado em 13/05/2026.**
