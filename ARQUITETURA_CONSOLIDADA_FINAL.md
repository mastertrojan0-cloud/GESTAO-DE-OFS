# ARQUITETURA CONSOLIDADA FINAL — Sistema OFS/OFS MVP

**Empresa:** Security Dynamics  
**Versão:** MVP 1.0 — Revisão Consolidada  
**Data:** 13/05/2026  
**Status:** Aprovado para implementação  

---

## 0. Decisão Sumária

| Decisão | Escolha Final |
|---------|---------------|
| **Frontend** | React 18 + Vite 5 + TypeScript + Tailwind CSS |
| **Backend** | FastAPI (Python 3.12) + Uvicorn (4 workers) |
| **ORM** | SQLAlchemy 2.0 async + Alembic |
| **Banco** | PostgreSQL 16 |
| **Auth** | JWT HS256 (access 15min + refresh 7d) + bcrypt cost 12 |
| **PDF** | WeasyPrint + Jinja2 + matplotlib |
| **Proxy** | Nginx Alpine |
| **Deploy** | Docker Compose (3 serviços) |
| **Scheduler** | APScheduler (interno ao backend) |

---

## 1. O que foi REMOVIDO do MVP

| # | Item removido | Agente | Motivo |
|---|--------------|--------|--------|
| 1 | Tabela `locais` | A1, A5 | Local é campo texto livre (`location_observed` VARCHAR) |
| 2 | Campo `empresa_usuario_snapshot` em ofc_records | A1 | Redundante (JOIN com users.company_id) |
| 3 | Campo `usuario_email_snapshot` em ofc_records | A1 | Rastreabilidade suficiente com nome + login + perfil |
| 4 | Endpoint `GET /api/metricas/mes` | A1 | Fora do MVP |
| 5 | Endpoint `GET /api/metricas/ranking-empresas` | A1 | Fase 2 |
| 6 | Endpoint `GET /api/metricas/ranking-usuarios` | A1 | Fase 2 |
| 7 | Endpoint `GET /api/relatorios/mes/pdf` | A1, A6 | Fora do MVP |
| 8 | Endpoint `GET /api/relatorios/semana/excel` | A1 | Fase 2 |
| 9 | Gráfico "OFS por Turno" (pizza) | A1, A4 | Menor valor analítico |
| 10 | Gráfico "Top Comportamentos" | A1, A4 | Fase 3 |
| 11 | Gráfico "Evolução Mensal" | A1, A4 | Fora do MVP |
| 12 | Gráfico "OFS por Usuário" (ranking) | A4 | Fase 3 |
| 13 | PDF Mensal completo | A6 | Fase 3 |
| 14 | PDF Ranking por Empresa | A6 | Fase 3 |
| 15 | PDF Ranking por Usuário | A6 | Fase 3 |
| 16 | PDF Histórico de Desvios | A6 | Fase 3 |
| 17 | Tela "OFS Salva (Sucesso)" como página | A4 | Substituída por toast |
| 18 | Botão "Salvar e Novo" | A4 | MVP = registro único |
| 19 | Botão "Salvar e Gerar PDF" | A4 | 2 cliques aceitável (Salvar → Detalhe → PDF) |
| 20 | Botão "Limpar" no formulário | A4 | Redundante com Cancelar |
| 21 | Botão "Imprimir" | A4 | PDF download substitui |
| 22 | Tela dedicada de Backup | A4 | Substituída por modal |
| 23 | Tela dedicada de Contratos | A4 | Sub-aba em Empresas |
| 24 | Container separado de backup | A7 | Substituído por APScheduler no backend |
| 25 | Template `monthly_report.html` | A6 | Apenas 2 templates no MVP |
| 26 | Template `company_report.html` | A6 | Apenas 2 templates no MVP |
| 27 | Função `build_monthly_report` | A6 | Apenas individual e semanal |
| 28 | Função `build_company_report` | A6 | Apenas individual e semanal |

---

## 2. O que foi SIMPLIFICADO

| # | Simplificação | Agente | Antes | Depois |
|---|-------------|--------|-------|--------|
| 1 | Telas do MVP | A4 | 15-16 telas | **12 telas** |
| 2 | Gráficos na tela Métricas | A4 | 8 gráficos | **4 gráficos** |
| 3 | Gráficos no PDF Semanal | A6 | 5 gráficos | **4 gráficos** |
| 4 | Botões no form Novo OFS | A4 | 4 botões | **2 botões** (Salvar + Cancelar) |
| 5 | Breakpoints CSS | A4 | 3 breakpoints | **2 breakpoints** (768px) |
| 6 | Campos no form OFS | A4 | 7 obrigatórios + extras | **6 campos + 2 opcionais** |
| 7 | Serviços Docker | A7 | 4 containers | **3 containers** |
| 8 | Template _base.html | A6 | ~460 linhas | **~160 linhas** |
| 9 | Endpoints totais | A3 | ~55+ | **47 endpoints** |
| 10 | Nginx config | A7 | Complexo | Essencial (proxy + static + headers) |
| 11 | Itens da Sidebar | A4 | 6 + 6 admin | **5 + 5 admin** |
| 12 | Tempo estimado registro OFS | A4 | ~3 min | **< 1 min** |

---

## 3. O que foi MANTIDO (já estava correto)

- Stack tecnológica (React+Vite, FastAPI, PostgreSQL, Docker, JWT, WeasyPrint)
- 4 perfis de acesso (Observador, Supervisor, Gestor, Admin)
- 15 empresas no dropdown + regra "Outros"
- 10 indicadores de métricas semanais
- Fórmulas de cálculo (aderência, % seguro, % desvio)
- Status OK/ATENÇÃO/ALERTA com cores semânticas
- Soft delete para cancelamento de OFS
- Janela de edição por perfil (24h/48h)
- Auditoria de todas as ações críticas
- Backup automático diário (03:00 AM)
- Identidade visual corporativa nos PDFs
- Offline-first (zero dependência externa)
- Deploy via Docker Compose
- Padrão de nomes de arquivo PDF
- Seeds iniciais (15 empresas + admin)

---

## 4. Arquitetura Consolidada Final

### 4.1 Diagrama de Serviços

```
┌──────────────────────────────────────────────────────────────────┐
│                 USUÁRIO (Browser — Intranet)                      │
│           http://servidor-interno:80                              │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│              NGINX :80 (Reverse Proxy + Static Files)             │
│  serve dist/ React SPA │ proxy /api/* → backend:8000             │
│  Security headers │ Gzip │ SPA try_files                         │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│               FASTAPI :8000 (Uvicorn 4 workers)                   │
│  ┌─────────┬──────────┬──────────┬──────────┬──────────┐         │
│  │  Auth   │  OFS     │ Consulta │ Metrics  │ Reports  │         │
│  │ JWT+bc  │  CRUD    │ FTS+CSV  │Weekly calc│ PDF gen  │         │
│  └─────────┴──────────┴──────────┴──────────┴──────────┘         │
│  ┌─────────┬──────────┬──────────┬──────────────────────┐        │
│  │  Users  │ Cadastros│  Audit   │  Backup (APScheduler)│        │
│  └─────────┴──────────┴──────────┴──────────────────────┘        │
└──────────────────────────┬───────────────────────────────────────┘
                           │ SQLAlchemy 2.0 async + asyncpg
┌──────────────────────────▼───────────────────────────────────────┐
│             PostgreSQL 16 (:5432, rede Docker interna)            │
│  8 tabelas core: companies │ users │ contracts │ targets          │
│                 ofc_records │ ofc_edit_log │ audit_logs │ reports │
│  + revoked_tokens │ backups                                       │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Módulos (8 módulos essenciais)

```
1. AUTH        — JWT login/refresh/logout, bcrypt, lockout (5 falhas/30min)
2. CADASTROS   — Users CRUD, Companies CRUD, Contracts CRUD, Targets CRUD
3. OFS RECORDS — Create, List, Detail, Edit (janela 24/48h), Cancel (soft delete)
4. CONSULTA    — Filtros dinâmicos (15 params), FTS português, CSV export
5. METRICS     — Weekly calc (10 indicadores), status OK/ATENÇÃO/ALERTA, 4 charts
6. REPORTS     — PDF individual, PDF semanal (WeasyPrint + matplotlib)
7. AUDIT       — Log de todas as ações críticas, consulta paginada (Admin)
8. BACKUP      — Automático (03:00 AM), manual, restore, rotação 30 dias
```

---

## 5. Banco de Dados Final (8 Tabelas Core)

```sql
-- 8 tabelas essenciais (nomes em inglês para consistência com ORM)

CREATE TABLE companies (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    is_custom   BOOLEAN DEFAULT FALSE,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

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
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE contracts (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE targets (
    id              SERIAL PRIMARY KEY,
    company_id      INT NOT NULL REFERENCES companies(id),
    contract_id     INT REFERENCES contracts(id),
    week_start      DATE NOT NULL,
    active_people   INT NOT NULL DEFAULT 1 CHECK (active_people >= 0),
    weekly_target   INT NOT NULL DEFAULT 5 CHECK (weekly_target >= 1),
    active_users    INT NOT NULL DEFAULT 1 CHECK (active_users >= 0),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (company_id, contract_id, week_start)
);

CREATE TABLE ofc_records (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequential_number   SERIAL,
    record_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    record_time         TIME NOT NULL DEFAULT CURRENT_TIME,
    week_num            INT GENERATED ALWAYS AS (EXTRACT(WEEK FROM record_date)::INT) STORED,
    month_num           INT GENERATED ALWAYS AS (EXTRACT(MONTH FROM record_date)::INT) STORED,
    year_num            INT GENERATED ALWAYS AS (EXTRACT(YEAR FROM record_date)::INT) STORED,
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

CREATE TABLE ofc_edit_log (
    id              BIGSERIAL PRIMARY KEY,
    ofc_record_id   UUID NOT NULL REFERENCES ofc_records(id),
    edited_by       UUID NOT NULL REFERENCES users(id),
    field_changed   VARCHAR(100) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ DEFAULT NOW()
);

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
    severity    VARCHAR(20) DEFAULT 'INFO',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type        VARCHAR(50) NOT NULL CHECK (type IN ('individual','semanal')),
    parameters  JSONB NOT NULL,
    file_path   VARCHAR(500),
    file_size   BIGINT,
    generated_by UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Tabelas de suporte
CREATE TABLE backups (
    id          SERIAL PRIMARY KEY,
    filename    VARCHAR(300) NOT NULL,
    file_path   VARCHAR(500) NOT NULL,
    size_bytes  BIGINT,
    type        VARCHAR(20) DEFAULT 'auto' CHECK (type IN ('auto','manual')),
    status      VARCHAR(20) DEFAULT 'success' CHECK (status IN ('success','failed')),
    error_msg   TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE revoked_tokens (
    id          SERIAL PRIMARY KEY,
    jti         VARCHAR(255) NOT NULL UNIQUE,
    user_id     UUID NOT NULL REFERENCES users(id),
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. APIs Consolidadas (47 Endpoints)

| # | Método | Path | Perfil Mínimo |
|---|--------|------|:---:|
| **Auth (5)** ||||
| 1 | `POST` | `/api/auth/login` | Público |
| 2 | `POST` | `/api/auth/refresh` | Autenticado |
| 3 | `POST` | `/api/auth/logout` | Autenticado |
| 4 | `GET` | `/api/auth/me` | Autenticado |
| 5 | `PUT` | `/api/auth/change-password` | Autenticado |
| **Users (5)** ||||
| 6 | `GET` | `/api/users` | Gestor |
| 7 | `GET` | `/api/users/{id}` | Gestor |
| 8 | `POST` | `/api/users` | Admin |
| 9 | `PUT` | `/api/users/{id}` | Admin |
| 10 | `PATCH` | `/api/users/{id}/status` | Admin |
| **Companies (5)** ||||
| 11 | `GET` | `/api/companies` | Autenticado |
| 12 | `GET` | `/api/companies/{id}` | Autenticado |
| 13 | `POST` | `/api/companies` | Admin |
| 14 | `PUT` | `/api/companies/{id}` | Admin |
| 15 | `PATCH` | `/api/companies/{id}/status` | Admin |
| **Contracts (5)** ||||
| 16 | `GET` | `/api/contracts` | Autenticado |
| 17 | `GET` | `/api/contracts/{id}` | Autenticado |
| 18 | `POST` | `/api/contracts` | Admin |
| 19 | `PUT` | `/api/contracts/{id}` | Admin |
| 20 | `PATCH` | `/api/contracts/{id}/status` | Admin |
| **Targets (5)** ||||
| 21 | `GET` | `/api/targets` | Autenticado |
| 22 | `GET` | `/api/targets/{id}` | Autenticado |
| 23 | `POST` | `/api/targets` | Gestor |
| 24 | `PUT` | `/api/targets/{id}` | Gestor |
| 25 | `GET` | `/api/targets/current` | Autenticado |
| **OFS Records (6)** ||||
| 26 | `POST` | `/api/OFS-records` | Observador |
| 27 | `GET` | `/api/OFS-records` | Observador+escopo |
| 28 | `GET` | `/api/OFS-records/{id}` | Observador+escopo |
| 29 | `PUT` | `/api/OFS-records/{id}` | Observador+janela |
| 30 | `PATCH` | `/api/OFS-records/{id}/cancel` | Gestor |
| 31 | `GET` | `/api/OFS-records/{id}/pdf` | Observador+escopo |
| **Consulta (2)** ||||
| 32 | `GET` | `/api/consulta` | Observador+escopo |
| 33 | `GET` | `/api/consulta/export-csv` | Observador+escopo |
| **Metrics (6)** ||||
| 34 | `GET` | `/api/metrics/weekly` | Supervisor |
| 35 | `GET` | `/api/metrics/charts/programmed-vs-realized` | Supervisor |
| 36 | `GET` | `/api/metrics/charts/positive-vs-negative` | Supervisor |
| 37 | `GET` | `/api/metrics/charts/by-company` | Gestor |
| 38 | `GET` | `/api/metrics/charts/by-user` | Supervisor |
| 39 | `GET` | `/api/metrics/charts/weekly-evolution` | Gestor |
| **Reports (3)** ||||
| 40 | `POST` | `/api/reports/generate` | Gestor (semanal) / Autenticado (individual) |
| 41 | `GET` | `/api/reports` | Autenticado |
| 42 | `GET` | `/api/reports/{id}/download` | Autenticado |
| **Audit (1)** ||||
| 43 | `GET` | `/api/audit` | Admin |
| **Backup (4)** ||||
| 44 | `GET` | `/api/backup/status` | Admin |
| 45 | `GET` | `/api/backup` | Admin |
| 46 | `POST` | `/api/backup/manual` | Admin |
| 47 | `POST` | `/api/backup/{id}/restore` | Admin |

---

## 7. Telas Consolidadas (12 Telas)

| # | Tela | Rota | Perfil Mínimo |
|---|------|------|:---:|
| 1 | Login | `/login` | Público |
| 2 | Dashboard | `/` | Observador |
| 3 | Novo Registro OFS | `/OFS/novo` | Observador |
| 4 | Lista de OFCs + Consulta | `/OFS` | Observador |
| 5 | Detalhe OFS | `/OFS/:id` | Observador (dono) |
| 6 | Editar OFS | `/OFS/:id/editar` | Observador (dono) |
| 7 | Métricas da Semana | `/metricas` | Supervisor |
| 8 | Relatórios | `/relatorios` | Gestor |
| 9 | Admin: Usuários | `/admin/usuarios` | Admin |
| 10 | Admin: Empresas + Contratos | `/admin/empresas` | Admin |
| 11 | Admin: Metas | `/admin/metas` | Gestor |
| 12 | Admin: Auditoria | `/admin/auditoria` | Admin |

---

## 8. Gráficos Consolidados (4 no MVP)

| # | Gráfico | Tipo | Frontend (Recharts) | PDF (matplotlib) |
|---|---------|------|:---:|:---:|
| 1 | Programado x Realizado | Barras | ✅ | ✅ |
| 2 | Positivo x Negativo | Rosca (Donut) | ✅ | ✅ |
| 3 | OFS por Empresa | Barras horizontais | ✅ | ✅ |
| 4 | Evolução Semanal (4-8 semanas) | Linha | ✅ | ✅ |

---

## 9. PDFs Consolidados (2 no MVP)

| # | PDF | Template | Gráficos | Tempo Esperado |
|---|-----|----------|:---:|:---:|
| 1 | Individual OFS/OFS | `individual_ofc.html` | 0 | < 2s |
| 2 | MÉTRICAS DA SEMANA | `weekly_metrics.html` | 4 | < 15s |

---

## 10. Infraestrutura Consolidada

### 10.1 docker-compose.yml (3 serviços)

```yaml
version: "3.9"
services:
  nginx:
    image: nginx:1.25-alpine
    ports: ["80:80"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./frontend/dist:/usr/share/nginx/html:ro
    depends_on: [backend]
    restart: unless-stopped
    read_only: true
    security_opt: [no-new-privileges:true]
    cap_drop: [ALL]
    cap_add: [NET_BIND_SERVICE]

  backend:
    build: ./backend
    expose: ["8000"]
    env_file: .env
    volumes:
      - ./reports:/app/reports
      - ./backups:/backups
      - ./logs:/app/logs
    depends_on: { db: { condition: service_healthy } }
    restart: unless-stopped
    deploy: { resources: { limits: { cpus: '2', memory: 1536M } } }
    healthcheck: { test: ["CMD", "curl", "-f", "http://localhost:8000/health"], interval: 30s, retries: 3 }

  db:
    image: postgres:16-alpine
    expose: ["5432"]
    environment: { POSTGRES_DB: ofs_db, POSTGRES_USER: ofs_user, POSTGRES_PASSWORD: ${DB_PASSWORD} }
    volumes: [pgdata:/var/lib/postgresql/data]
    restart: unless-stopped
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U ofs_user -d ofs_db"], interval: 10s, retries: 5 }

volumes:
  pgdata:
```

### 10.2 Requisitos do Servidor

| Componente | Mínimo |
|-----------|--------|
| CPU | 2 vCPUs |
| RAM | 4 GB |
| Disco | 50 GB SSD |
| SO | Ubuntu Server 22.04 LTS |
| Docker | 24+ com Compose v2 |
| Rede | IP fixo na intranet |

### 10.3 Backup

| Tipo | Frequência | Retenção |
|------|-----------|----------|
| Diário (auto) | 03:00 AM | 30 dias |
| Semanal (auto) | Domingo 03:00 | 12 semanas |
| Manual | Sob demanda | Ilimitado |

### 10.4 Segurança

| Camada | Proteção |
|--------|----------|
| Senhas | bcrypt cost 12, mínimo 8 chars |
| Token | JWT HS256, access 15min + refresh 7d |
| Lockout | 5 falhas → 30 minutos |
| RBAC | 4 perfis com data scoping |
| Headers | CSP, X-Frame-Options, X-XSS-Protection, Referrer-Policy |
| Docker | non-root, read_only, cap_drop ALL, no-new-privileges |
| Auditoria | Todas ações críticas registradas |

---

## 11. Performance — Metas e Otimizações

| Métrica | Alvo |
|---------|:---:|
| Login | < 200ms |
| Criar OFS | < 80ms |
| Listar OFCs (25/página) | < 150ms |
| Métricas semanais | < 300ms |
| PDF individual | < 2s |
| PDF semanal (4 gráficos) | < 15s |
| Bundle frontend inicial | < 100KB gzip |
| Primeira pintura (LCP) | < 1.5s |

### Otimizações Críticas Implementadas

1. Índices compostos para métricas e consultas
2. Cache TTL 5min para dropdowns (empresas, contratos)
3. Bundle splitting (React, Recharts, Lucide separados)
4. Lazy loading de gráficos e páginas admin
5. PDF com ProcessPoolExecutor (não bloqueia worker)
6. Logo carregado 1x como singleton (base64 em memória)
7. Autovacuum agressivo na tabela ofc_records (scale_factor 0.01)
8. Uvicorn 4 workers com limit-concurrency 100

---

## 12. Validação: Zero Mídia/Upload

**Confirmado:** Nenhum endpoint aceita `multipart/form-data`. Nenhum schema Pydantic contém `UploadFile`. Nenhum componente React contém `<input type="file">`. O sistema é 100% textual. Toda rastreabilidade vem de: usuário logado, data/hora, empresa, local (texto), turno, tipo, comportamento descrito, observação complementar, histórico de edições e logs de auditoria.

---

## 13. Plano de Execução (5 Sprints)

| Sprint | Semanas | Foco |
|--------|:---:|-------|
| **Sprint 0** | 1-2 | Ambiente, Docker, estrutura, migrations |
| **Sprint 1** | 3-6 | Banco + Auth + Cadastros + RBAC |
| **Sprint 2** | 7-10 | OFS CRUD + Consulta |
| **Sprint 3** | 11-14 | Métricas + PDFs + Gráficos |
| **Sprint 4** | 15-18 | Auditoria + Backup + Homologação |

| Cenário | Duração |
|---------|:---:|
| Time completo (6 pessoas) | 12 semanas |
| Time enxuto (3 pessoas) | 18 semanas |
| Desenvolvedor único | 26 semanas |

---

## 14. Checklist de Validação Final

- [x] Stack definida e justificada
- [x] 47 endpoints mapeados com permissões
- [x] 8 tabelas core + 3 de suporte
- [x] 12 telas essenciais
- [x] 4 gráficos (frontend + PDF)
- [x] 2 PDFs (individual + semanal)
- [x] Docker Compose com 3 serviços
- [x] Backup automático funcional
- [x] RBAC 4 perfis implementado
- [x] Auditoria de todas ações críticas
- [x] Zero upload/mídia/anexos
- [x] Zero dependência externa (offline-first)
- [x] Preparado para migração cloud (env vars, stateless)
- [x] Performance targets definidos
- [x] Plano de sprints com estimativas

---

**Documento gerado em 13/05/2026. Pronto para iniciar Sprint 0.**
