# PLANO MESTRE — Sistema de Feedback Comportamental OFS/OFS

**Empresa:** Security Dynamics  
**Versão:** 1.0  
**Data:** 13/05/2026  
**Status:** Plano de Arquitetura e Desenvolvimento  

---

## Sumário

1. [Arquitetura Final Recomendada](#1-arquitetura-final-recomendada)
2. [Stack Técnica](#2-stack-técnica)
3. [Diagrama Lógico dos Módulos](#3-diagrama-lógico-dos-módulos)
4. [Modelo do Banco de Dados](#4-modelo-do-banco-de-dados)
5. [Fluxo de Funcionamento do Sistema](#5-fluxo-de-funcionamento-do-sistema)
6. [Estrutura das Telas](#6-estrutura-das-telas)
7. [Regras de Negócio](#7-regras-de-negócio)
8. [Regras de Acesso (RBAC)](#8-regras-de-acesso-rbac)
9. [Estrutura dos Relatórios e PDF](#9-estrutura-dos-relatórios-e-pdf)
10. [Estratégia de Backup](#10-estratégia-de-backup)
11. [Estratégia de Segurança e Auditoria](#11-estratégia-de-segurança-e-auditoria)
12. [Plano de Desenvolvimento MVP](#12-plano-de-desenvolvimento-mvp)
13. [Riscos Técnicos](#13-riscos-técnicos)
14. [Melhorias Futuras](#14-melhorias-futuras)

---

## 1. Arquitetura Final Recomendada

### 1.1 Visão Geral

```
┌──────────────────────────────────────────────────────────────┐
│                   USUÁRIO (Browser)                           │
│            http://servidor-interno:80                         │
│            Desktop / Tablet / Mobile                          │
└─────────────────────────┬────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────┐
│                    NGINX :80/:443                              │
│  • Serve arquivos estáticos (React build)                     │
│  • Proxy reverso /api/* → Backend                             │
│  • Security headers (CSP, X-Frame-Options, etc.)              │
│  • Gzip/Brotli compression                                    │
└─────────────────────────┬────────────────────────────────────┘
                          │ /api/*
┌─────────────────────────▼────────────────────────────────────┐
│                FASTAPI (Uvicorn) :8000                         │
│  ┌──────────┬──────────┬──────────┬──────────────────┐       │
│  │   Auth   │   OFS    │ Metrics  │    Reports/PDF   │       │
│  │  (JWT)   │  (CRUD)  │ (Cache)  │ (WeasyPrint+Matp)│       │
│  └──────────┴──────────┴──────────┴──────────────────┘       │
│  ┌──────────┬──────────┬──────────┬──────────────────┐       │
│  │  Users   │ Consulta │  Audit   │    Backup        │       │
│  │ (Roles)  │ (Search) │  (Log)   │ (APScheduler)    │       │
│  └──────────┴──────────┴──────────┴──────────────────┘       │
└─────────────────────────┬────────────────────────────────────┘
                          │ SQLAlchemy 2.0 (async)
┌─────────────────────────▼────────────────────────────────────┐
│               PostgreSQL 16 :5432                              │
│  Tables: users │ companies │ contracts │ targets              │
│          ofc_records │ ofc_edit_log │ audit_logs              │
│          reports │ backups │ revoked_tokens                   │
│  Views:  vw_weekly_metrics, vw_daily_counts                   │
│  Functions: calculate_weekly_metrics(), count_by_type()       │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Arquitetura: Modular Monolith

Optou-se por um **monolito modular** em vez de microserviços pelas seguintes razões:

| Critério | Monolito Modular | Microserviços |
|----------|-----------------|---------------|
| Complexidade inicial | Baixa | Alta |
| Deploy | 3 containers | 10+ containers |
| Latência interna | Função call | Rede (ms) |
| Transações | ACID natural | Saga pattern |
| Debug | Simples | Distribuído |
| Migração futura | Extrair módulos gradualmente | Já nasce distribuído |

**Decisão:** Monolito modular agora, com contratos de serviço bem definidos para extração futura.

---

## 2. Stack Técnica

### 2.1 Frontend

| Tecnologia | Versão | Justificativa |
|-----------|--------|---------------|
| React | 18.x | SPA madura, ecossistema amplo, tree-shaking |
| Vite | 5.x | Build ultrarrápido, offline-ready, assets com hash |
| TypeScript | 5.x | Tipagem estática, menos bugs em produção |
| Tailwind CSS | 3.x | CSS utilitário, bundle final ~10KB, sem CDN |
| Zustand | 4.x | State management leve (~1KB), sem boilerplate |
| React Router | 6.x | Roteamento SPA, lazy loading nativo |
| Recharts | 2.x | Gráficos SVG declarativos, ~50KB, reativo |
| Lucide React | 0.x | Ícones SVG como componentes, tree-shaking |
| Axios | 1.x | HTTP client com interceptors para 401/403 |
| Sonner | 1.x | Toast notifications (~3KB) |

### 2.2 Backend

| Tecnologia | Versão | Justificativa |
|-----------|--------|---------------|
| Python | 3.12 | Maturidade, ecossistema para PDF/gráficos |
| FastAPI | 0.111+ | Async nativo, OpenAPI automático, validação Pydantic |
| Uvicorn | 0.29+ | ASGI server de alta performance |
| SQLAlchemy | 2.0+ | ORM async, migrações com Alembic, PostgreSQL nativo |
| Pydantic | 2.x | Validação de schemas, serialização rápida |
| python-jose | 3.x | JWT encode/decode |
| passlib | 1.7+ | bcrypt hashing (cost factor 12) |
| WeasyPrint | 61+ | HTML/CSS → PDF, sem browser, CSS Paged Media |
| matplotlib | 3.8+ | Gráficos PNG de alta qualidade para PDF |
| ReportLab | 4.x | PDF programático (complementar) |
| Jinja2 | 3.x | Templates HTML para PDF |
| APScheduler | 3.x | Tarefas agendadas (backup diário) |
| asyncpg | 0.29+ | Driver PostgreSQL async de alta performance |

### 2.3 Infraestrutura

| Tecnologia | Justificativa |
|-----------|---------------|
| PostgreSQL 16 | ACID, JSONB, full-text search, replicação, RDS-ready |
| Docker + Compose | 4 containers, deploy consistente, portable |
| Nginx | Reverse proxy, static files, security headers, compressão |
| pg_dump / pg_restore | Backup nativo, formato custom comprimido |

### 2.4 O que NÃO usar (e por quê)

| Tecnologia rejeitada | Motivo |
|---------------------|--------|
| Next.js | Pesado para SPA interna, SSR desnecessário em intranet |
| Puppeteer | Chromium 300MB+ para empacotar offline, overkill |
| SQLite | 1 escritor por vez, inviável para 50+ usuários concorrentes |
| CDN externa | Sistema offline, sem internet |
| Google Fonts | Fontes locais (Inter .woff2), sem requisição externa |
| Redis (MVP) | Cache em memória (cachetools.TTLCache) suficiente para início |
| Celery (MVP) | Geração de PDF síncrona aceitável no MVP |

---

## 3. Diagrama Lógico dos Módulos

```
┌─────────────────────────────────────────────────────────────────┐
│                        SISTEMA OFS/OFS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Auth    │  │  Users   │  │Companies │  │  Contracts    │  │
│  │  Module  │◄─┤  Module  │  │ Module   │  │  Module       │  │
│  │          │  │          │  │          │  │               │  │
│  │ • Login  │  │ • CRUD   │  │ • CRUD   │  │ • CRUD        │  │
│  │ • JWT    │  │ • Perfis │  │ • Lista  │  │ • Por empresa │  │
│  │ • RBAC   │  │ • Status │  │ • Seed   │  │               │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│       │              │              │                │          │
│       ▼              ▼              ▼                ▼          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    OFS Records Module                     │  │
│  │  • Criar / Editar / Cancelar / Visualizar                 │  │
│  │  • Validações de negócio (janela de edição, permissões)   │  │
│  │  • Soft delete (is_deleted)                               │  │
│  │  • Histórico de edições (ofc_edit_log)                    │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                            │                                     │
│       ┌────────────────────┼────────────────────┐               │
│       ▼                    ▼                    ▼               │
│  ┌──────────┐  ┌──────────────────┐  ┌──────────────────┐      │
│  │ Consulta │  │    Metrics       │  │    Reports/PDF   │      │
│  │ Module   │  │    Module        │  │    Module        │      │
│  │          │  │                  │  │                  │      │
│  │ •Filtros │  │ •Weekly calc    │  │ •Generate PDF    │      │
│  │ •CSV     │  │ •Status OK/AT/AL│  │ •Charts (PNG)    │      │
│  │ •FTS     │  │ •Dashboard data │  │ •Download        │      │
│  └──────────┘  └──────────────────┘  └──────────────────┘      │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Cross-Cutting Modules                   │  │
│  │  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │  │
│  │  │  Audit   │  │   Backup     │  │   Scheduler      │   │  │
│  │  │  Module  │  │   Module     │  │   Module         │   │  │
│  │  │          │  │              │  │                  │   │  │
│  │  │ •Log all │  │ •Auto daily  │  │ •Backup 03:00   │   │  │
│  │  │ •Query   │  │ •Manual trig │  │ •Token cleanup  │   │  │
│  │  │ •Export  │  │ •Restore     │  │ •Metrics cache  │   │  │
│  │  └──────────┘  └──────────────┘  └──────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Modelo do Banco de Dados

### 4.1 Diagrama Entidade-Relacionamento

```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│  companies  │       │   contracts  │       │   targets   │
├─────────────┤       ├──────────────┤       ├─────────────┤
│ id (PK)     │──┐    │ id (PK)      │   ┌──│ id (PK)     │
│ name        │  │    │ name         │   │  │ company_id  │──┐
│ is_custom   │  │    │ company_id   │───┤  │ contract_id │  │
│ is_active   │  │    │ description  │   │  │ daily_target│  │
│ created_at  │  │    │ is_active    │   │  │ weekly_trgt │  │
└──────┬──────┘  │    │ created_at   │   │  │ active_ppl  │  │
       │         │    └──────────────┘   │  │ active_usr  │  │
       │         │                       │  │ valid_from  │  │
       │         └───────────┐           │  │ valid_until │  │
       │                     │           │  │ is_active   │  │
       ▼                     ▼           │  │ created_at  │  │
┌─────────────┐       ┌──────────────┐   │  └─────────────┘  │
│    users    │       │ ofc_records  │   │                   │
├─────────────┤       ├──────────────┤   │                   │
│ id (PK)     │──┐    │ id (PK)      │   │                   │
│ username    │  │    │ seq_number   │   │                   │
│ password_h  │  │    │ record_date  │   │                   │
│ full_name   │  │    │ record_time  │   │                   │
│ email       │  │    │ generated_by │◄──┘                   │
│ role        │  │    │ observed_name│                       │
│ company_id  │──┤    │ activity_obs │                       │
│ is_active   │  │    │ location_obs │                       │
│ last_login  │  │    │ company_id   │───────────────────────┘
│ created_at  │  │    │ shift        │
│ updated_at  │  │    │ type         │
└─────────────┘  │    │ behavior_obs │
                 │    │ comp_obs     │
                 │    │ status       │
                 │    │ is_deleted   │
                 │    │ deleted_by   │──┐
                 │    │ created_at   │  │
                 │    │ updated_at   │  │
                 │    └──────┬───────┘  │
                 │           │          │
                 │           ▼          │
                 │    ┌──────────────┐  │
                 │    │ofc_edit_log  │  │
                 │    ├──────────────┤  │
                 │    │ id (PK)      │  │
                 │    │ ofc_id (FK)  │  │
                 │    │ edited_by    │──┤
                 │    │ field_changed│  │
                 │    │ old_value    │  │
                 │    │ new_value    │  │
                 │    │ edited_at    │  │
                 │    └──────────────┘  │
                 │                      │
┌─────────────┐  │                      │
│ audit_logs  │  │                      │
├─────────────┤  │                      │
│ id (PK)     │  │                      │
│ timestamp   │  │                      │
│ user_id     │──┘──────────────────────┘
│ action      │
│ resource    │
│ resource_id │
│ details     │ (JSONB)
│ ip_address  │
│ created_at  │
└─────────────┘

┌─────────────┐       ┌──────────────┐       ┌───────────────┐
│  reports    │       │   backups    │       │revoked_tokens │
├─────────────┤       ├──────────────┤       ├───────────────┤
│ id (PK)     │       │ id (PK)      │       │ id (PK)       │
│ type        │       │ filename     │       │ jti           │
│ title       │       │ file_path    │       │ user_id (FK)  │
│ parameters  │       │ size_bytes   │       │ expires_at    │
│ file_path   │       │ type         │       │ revoked_at    │
│ file_size   │       │ status       │       └───────────────┘
│ page_count  │       │ error_msg    │
│ gen_by (FK) │       │ created_at   │
│ created_at  │       └──────────────┘
└─────────────┘
```

### 4.2 Tabelas (10 tabelas principais)

| # | Tabela | Registros esperados | Descrição |
|---|--------|---------------------|-----------|
| 1 | `companies` | ~20 | Empresas cadastradas (15 pré-cadastradas + customizadas) |
| 2 | `users` | ~200 | Usuários do sistema com perfis |
| 3 | `contracts` | ~50 | Contratos por empresa |
| 4 | `targets` | ~500/ano | Metas semanais por empresa/contrato |
| 5 | `ofc_records` | ~50.000/ano | Registros OFS/OFS (tabela principal) |
| 6 | `ofc_edit_log` | ~5.000/ano | Histórico de edições |
| 7 | `audit_logs` | ~100.000/ano | Logs de auditoria |
| 8 | `reports` | ~500/ano | Relatórios PDF gerados |
| 9 | `backups` | ~50 | Histórico de backups |
| 10 | `revoked_tokens` | ~2.000 | Tokens JWT revogados |

### 4.3 Índices Otimizados

```sql
-- Performance de consulta por período
CREATE INDEX idx_ofc_date_company ON ofc_records(record_date, company_id);

-- Filtros comuns
CREATE INDEX idx_ofc_type ON ofc_records(type);
CREATE INDEX idx_ofc_status ON ofc_records(status);
CREATE INDEX idx_ofc_generated_by ON ofc_records(generated_by);

-- Full-text search (português)
CREATE INDEX idx_ofc_fts ON ofc_records 
  USING GIN(to_tsvector('portuguese', behavior_observed || ' ' || complementary_observation));

-- Auditoria  
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id, timestamp DESC);

-- Métricas rápidas
CREATE INDEX idx_ofc_metrics ON ofc_records(company_id, record_date, type) 
  WHERE is_deleted = FALSE;
```

### 4.4 Estratégia de Particionamento (Fase 2)

- Particionar `ofc_records` por mês (`record_date`)
- 12 partições por ano, criação automática via trigger
- Facilita queries por período e purga de dados antigos

### 4.5 Seed Inicial

- 15 empresas pré-cadastradas
- 1 usuário admin: `admin` / `admin123` (bcrypt)
- Senha deve ser alterada no primeiro acesso

---

## 5. Fluxo de Funcionamento do Sistema

### 5.1 Fluxo Principal

```
┌─────────┐     ┌─────────────┐     ┌──────────────┐     ┌────────────┐
│  LOGIN  │────▶│  DASHBOARD  │────▶│  NOVO OFS    │────▶│  LISTA OFS │
│         │     │             │     │  (registro)   │     │  (consulta)│
└─────────┘     └──────┬──────┘     └──────────────┘     └────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ MÉTRICAS │ │RELATÓRIOS│ │  ADMIN   │
   │ DA SEMANA│ │   PDF    │ │ (gestão) │
   └──────────┘ └──────────┘ └──────────┘
```

### 5.2 Fluxo de Registro OFS/OFS

```
1. Usuário clica "Novo OFS"
2. Sistema preenche automaticamente:
   - ID (UUID)
   - Data atual
   - Hora atual
   - Usuário gerador (nome, login, perfil, empresa)
3. Usuário seleciona:
   - Empresa observada (dropdown com 15 empresas + "Outros")*
   - *Se "Outros" → campo texto obrigatório
4. Usuário preenche:
   - Nome do observado
   - Atividade observada
   - Local
   - Turno (dropdown)
   - Tipo (Positivo/Seguro ou Negativo/Inseguro)
   - Comportamento observado
   - Observação complementar (opcional)
5. Clica "Salvar" ou "Salvar e Novo"
6. Registro criado com status="ativo"
7. Audit log registrado
8. Toast de confirmação
```

### 5.3 Fluxo de Métricas da Semana

```
1. Usuário acessa /metricas
2. Sistema busca metas vigentes (targets)
3. Sistema calcula:
   → OFS Programadas = Pessoas Ativas × Meta Semanal
   → OFS Realizadas = COUNT(ofc_records) no período
   → Aderência % = Realizadas ÷ Programadas × 100
   → Positivas / Negativas
   → % Seguro / % Desvio
   → Usuários Ativos / Média OFS por Usuário
4. Sistema classifica:
   → OK (≥100%) = Verde
   → ATENÇÃO (80-99%) = Amarelo
   → ALERTA (<80%) = Vermelho
5. Exibe dashboard com cards, tabelas e gráficos
```

---

## 6. Estrutura das Telas

### 6.1 Mapa de Rotas (16 telas)

| Rota | Tela | Perfil Mínimo |
|------|------|---------------|
| `/login` | Login | Público |
| `/` | Dashboard Principal | Observador |
| `/OFS/novo` | Novo Registro OFS/OFS | Observador |
| `/OFS` | Lista de OFCs | Observador |
| `/OFS/:id` | Detalhe do OFS | Observador |
| `/OFS/:id/editar` | Editar OFS | Observador (dono) |
| `/consulta` | Consulta Avançada | Observador |
| `/metricas` | Métricas da Semana + Gráficos | Supervisor |
| `/relatorios` | Relatórios PDF | Gestor |
| `/admin/usuarios` | Gestão de Usuários | Gestor/Admin |
| `/admin/empresas` | Gestão de Empresas | Admin |
| `/admin/contratos` | Gestão de Contratos | Gestor/Admin |
| `/admin/metas` | Gestão de Metas | Gestor/Admin |
| `/admin/auditoria` | Logs de Auditoria | Admin |
| `/admin/backup` | Backup e Restauração | Admin |

### 6.2 Layout Base

```
┌─────────────────────────────────────────────────────────┐
│ ┌──────────┐  ┌──────────────────────────────────────┐  │
│ │          │  │  [LOGO SD]  SISTEMA OFS/OFS  [👤] [↗] │  │ ← Header
│ │  SIDEBAR │  ├──────────────────────────────────────┤  │
│ │          │  │                                      │  │
│ │ 📊 Dash  │  │        CONTEÚDO PRINCIPAL             │  │
│ │ 📝 Novo  │  │        (Outlet da rota)               │  │
│ │ 📋 Lista │  │                                      │  │
│ │ 🔍 Cons. │  │                                      │  │
│ │ 📈 Mét.  │  │                                      │  │
│ │ 📄 Rel.  │  │                                      │  │
│ │ ─────── │  │                                      │  │
│ │ ⚙ Admin  │  │                                      │  │
│ │          │  │                                      │  │
│ └──────────┘  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 6.3 Responsividade

| Breakpoint | Comportamento |
|-----------|---------------|
| >1024px | Sidebar fixa à esquerda, tabelas completas |
| 768-1024px | Sidebar colapsável (hamburger), tabelas com scroll |
| <768px | Navegação bottom tab, cards no lugar de tabelas |

### 6.4 Identidade Visual

| Elemento | Valor |
|----------|-------|
| Cor primária | Vermelho institucional `#CC0000` |
| Cor secundária | Preto `#1A1A1A` |
| Background | Cinza claro `#F5F5F5` |
| Superfície | Branco `#FFFFFF` |
| Sucesso | Verde `#22C55E` |
| Alerta | Amarelo `#EAB308` |
| Perigo | Vermelho `#EF4444` |
| Fonte | Inter (local, .woff2) |
| Logo | Security Dynamics no header e login |

---

## 7. Regras de Negócio

### 7.1 Criação de OFS/OFS

- ID UUID gerado automaticamente
- Número sequencial (SERIAL) visível como "Nº OFS"
- Data e hora do servidor (não do cliente)
- Usuário logado vinculado automaticamente como `generated_by`
- Empresa do usuário como padrão, editável
- Se Empresa = "Outros", `custom_company_name` torna-se obrigatório
- Tipo validado: apenas "Positivo/Seguro" ou "Negativo/Inseguro"
- Status inicial: "ativo"

### 7.2 Edição de OFS/OFS

| Perfil | Pode editar | Janela de tempo |
|--------|------------|-----------------|
| Observador | Apenas seus próprios registros | Até 24h da criação |
| Supervisor | Registros da sua empresa | Até 48h da criação |
| Gestor | Qualquer registro | Sem limite |
| Admin | Qualquer registro | Sem limite |

- Cada campo alterado gera registro em `ofc_edit_log`
- Status muda para "editado"
- Contador `edit_count` incrementado
- Audit log registrado com campos alterados

### 7.3 Cancelamento de OFS/OFS

- Apenas Gestor e Admin podem cancelar
- Soft delete: `is_deleted = TRUE`, `deleted_at = NOW()`, `deleted_by = user_id`
- Status muda para "cancelado"
- Registro nunca é excluído fisicamente
- Cancelados não entram nas métricas
- Apenas Admin pode restaurar um registro cancelado

### 7.4 Cálculo de Métricas

```
OFS Programadas = Pessoas Ativas × Meta Semanal por Pessoa
Aderência %      = (OFS Realizadas ÷ OFS Programadas) × 100
% Seguro         = (OFS Positivas ÷ OFS Realizadas) × 100
% Desvio         = (OFS Negativas ÷ OFS Realizadas) × 100
Média OFS/Usuário = OFS Realizadas ÷ Usuários Ativos
```

**Classificação de Status:**
| Aderência | Status | Cor |
|-----------|--------|-----|
| ≥ 100% | OK | 🟢 Verde |
| 80% - 99% | ATENÇÃO | 🟡 Amarelo |
| < 80% | ALERTA | 🔴 Vermelho |

### 7.5 Validações de Negócio

- `observed_name`: obrigatório, mínimo 3 caracteres
- `behavior_observed`: obrigatório, mínimo 5 caracteres
- `type`: apenas valores do enum
- `shift`: apenas valores do enum (Diurno, Noturno, Misto, ADM)
- Não permitir registros com data futura
- Não permitir editar registros cancelados
- Optimistic locking com `updated_at` para prevenir conflitos

---

## 8. Regras de Acesso (RBAC)

### 8.1 Matriz de Permissões

| Ação | Observador | Supervisor | Gestor | Admin |
|------|:---:|:---:|:---:|:---:|
| **OFS/OFS** | | | | |
| Criar OFS | ✅ | ✅ | ✅ | ✅ |
| Ver OFS | Apenas seus | Sua empresa | Todas | Todas |
| Editar OFS | Seu, até 24h | Empresa, até 48h | Sem limite | Sem limite |
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Restaurar OFS | ❌ | ❌ | ❌ | ✅ |
| Exportar CSV | Seus | Sua empresa | Todas | Todas |
| **Métricas** | | | | |
| Ver métricas | ❌ | Sua empresa | Todas | Todas |
| Ver gráficos | ❌ | Sua empresa | Todas | Todas |
| **Relatórios PDF** | | | | |
| PDF individual | Seus | Empresa | Todos | Todos |
| PDF semanal | ❌ | ❌ | ✅ | ✅ |
| PDF mensal | ❌ | ❌ | ✅ | ✅ |
| **Administração** | | | | |
| Gerenciar usuários | ❌ | ❌ | Sua empresa | Todos |
| Gerenciar empresas | ❌ | ❌ | ❌ | ✅ |
| Gerenciar contratos | ❌ | ❌ | Sua empresa | Todos |
| Gerenciar metas | ❌ | ❌ | Sua empresa | Todos |
| Ver auditoria | ❌ | ❌ | ❌ | ✅ |
| Backup/Restore | ❌ | ❌ | ❌ | ✅ |

### 8.2 Filtros de Visibilidade (Data Scoping)

```python
# Aplicado em todas as queries de listagem
if user.role == "observador":
    query = query.where(OfcRecord.generated_by == user.id)
elif user.role == "supervisor":
    query = query.where(OfcRecord.company_id == user.company_id)
# gestor e admin: sem filtro adicional
```

### 8.3 Implementação Técnica

- Middleware FastAPI extrai e valida JWT
- `Depends(get_current_user)` injeta usuário autenticado
- `Depends(require_role("admin", "gestor"))` verifica perfil
- Serviços aplicam filtros de escopo de dados
- Frontend: `ProtectedRoute` com verificação de role

---

## 9. Estrutura dos Relatórios e PDF

### 9.1 Tipos de Relatório

| Tipo | Descrição | Perfil Mínimo |
|------|-----------|---------------|
| Individual | Um OFS específico | Observador (dono) |
| Semanal | Métricas da Semana (completo) | Gestor |
| Mensal | Comparativo 4-5 semanas + tendência | Gestor |
| Por Empresa | Todos OFCs de uma empresa no período | Gestor |

### 9.2 Layout PDF (WeasyPrint HTML/CSS)

```
┌──────────────────────────────────────────────┐ ← Margem 20mm
│  [LOGO SD]    SISTEMA DE FEEDBACK            │ ← Header (cada página)
│  ───────────────────────────────────────────│ ← Linha vermelha 1pt
│                                              │
│  RELATÓRIO SEMANAL DE MÉTRICAS               │ ← Título 18pt Bold
│  Semana: 11/05/2026 a 17/05/2026             │ ← Subtítulo 14pt
│  Empresa: Security Dynamics                  │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ INDICADOR           │ VALOR  │ STATUS│    │ ← Tabela cabeçalho
│  ├──────────────────────────────────────┤    │   vermelho com texto
│  │ Pessoas Ativas      │ 150    │       │    │   branco
│  │ OFS Programadas     │ 450    │       │    │
│  │ OFS Realizadas      │ 387    │       │    │
│  │ Aderência %         │ 86.0%  │ATENÇÃO│    │ ← Linhas alternadas
│  │ Positivas           │ 320    │       │    │
│  │ Negativas           │ 67     │       │    │
│  │ % Seguro            │ 82.7%  │       │    │
│  │ % Desvio            │ 17.3%  │       │    │
│  │ Usuários Ativos     │ 28     │       │    │
│  │ Média OFS/Usuário   │ 13.8   │       │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  [GRÁFICO: Programado x Realizado]           │ ← PNG matplotlib
│  [GRÁFICO: Positivo x Negativo]              │
│  [GRÁFICO: Evolução Semanal]                 │
│                                              │
│  TOP 5 COMPORTAMENTOS SEGUROS                │
│  ┌──────────────────────────────────────┐    │
│  │ # │ Comportamento          │ Ocorr.  │    │
│  │ 1 │ Uso correto de EPI     │ 45      │    │
│  │ 2 │ Sinalização adequada   │ 38      │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ───────────────────────────────────────────│ ← Rodapé linha vermelha
│  Gerado em: 13/05/2026 14:30 │ Página 1/3   │ ← Rodapé (cada página)
│  Security Dynamics - Documento gerado        │
│  automaticamente pelo Sistema OFS/OFS        │
└──────────────────────────────────────────────┘
```

### 9.3 Gráficos Incluídos nos PDFs

| # | Gráfico | Tipo | Descrição |
|---|---------|------|-----------|
| 1 | Programado x Realizado | Barras lado a lado | Comparação visual |
| 2 | Positivo x Negativo | Rosca (donut) | Distribuição percentual |
| 3 | OFS por Empresa | Barras horizontais | Ranking de empresas |
| 4 | OFS por Usuário | Barras verticais | Top geradores |
| 5 | OFS por Turno | Pizza | Distribuição por turno |
| 6 | Top Comportamentos | Barras horizontais | Mais frequentes |
| 7 | Evolução Semanal | Linha | Tendência 4-8 semanas |
| 8 | Evolução Mensal | Linha | Tendência 6-12 meses |

### 9.4 Pipeline de Geração

```
POST /api/reports/generate
    │
    ▼
report_service.generate_report()
    │
    ├──▶ Busca dados no PostgreSQL
    │
    ├──▶ chart_service.py → matplotlib → PNG (temp)
    │
    ├──▶ pdf_service.py → Jinja2 template + dados + PNG base64 → WeasyPrint → PDF bytes
    │
    ├──▶ Salva PDF em /app/reports/
    │
    ├──▶ Cria registro em reports table
    │
    └──▶ Retorna download_url
```

---

## 10. Estratégia de Backup

### 10.1 Política de Backup

| Tipo | Frequência | Retenção |
|------|-----------|----------|
| Backup diário automático | 03:00 AM | 30 dias |
| Backup semanal | Domingo | 12 semanas |
| Backup mensal | Dia 1 | 12 meses |
| Backup manual | Sob demanda | Ilimitado (admin decide) |

### 10.2 Procedimento

1. APScheduler dispara `pg_dump` diariamente às 03:00
2. Formato: custom comprimido (`.dump`)
3. Nomenclatura: `backup_YYYY-MM-DD_HHmmss.dump`
4. Armazenamento primário: volume Docker `./backups/`
5. Armazenamento secundário: cópia para NAS/pasta de rede (script pós-backup)
6. Verificação de integridade: `pg_restore --list` após dump

### 10.3 Restauração

1. Admin acessa `/admin/backup`
2. Seleciona backup da lista
3. Confirma com senha + checkbox "Estou ciente da perda de dados"
4. Sistema executa `pg_restore` com banco em modo manutenção
5. Audit log registrado como CRITICAL

### 10.4 Disaster Recovery

**RTO (Recovery Time Objective):** < 2 horas  
**RPO (Recovery Point Objective):** < 24 horas

```
1. Provisionar novo servidor (Windows/Linux)
2. Instalar Docker + Docker Compose
3. Copiar docker-compose.yml e .env
4. Copiar último backup (.dump)
5. docker compose up -d db
6. pg_restore no banco
7. docker compose up -d
8. Validar acesso web
```

---

## 11. Estratégia de Segurança e Auditoria

### 11.1 Autenticação

- **JWT**: Access Token (15 min) + Refresh Token (7 dias)
- **Algoritmo**: HS256 com secret >= 256 bits
- **Senhas**: bcrypt com cost factor 12
- **Lockout**: 5 tentativas falhas → bloqueio 30 minutos
- **Histórico**: não permitir reuso das últimas 5 senhas
- **Expiração**: 90 dias (configurável)
- **Logout**: revoga refresh token (blacklist)

### 11.2 Auditoria

Todos os eventos abaixo geram registro em `audit_logs`:

| Evento | Severidade |
|--------|-----------|
| LOGIN_SUCCESS / LOGIN_FAILED | INFO / WARNING |
| OFC_CREATE / UPDATE / CANCEL | INFO / WARNING / WARNING |
| OFC_RESTORE | WARNING |
| USER_CREATE / UPDATE / DISABLE | WARNING |
| TARGET_UPDATE | WARNING |
| REPORT_GENERATE | INFO |
| BACKUP_MANUAL / BACKUP_RESTORE | INFO / CRITICAL |
| PERMISSION_DENIED | WARNING |

### 11.3 Proteções OWASP Top 10

| Vulnerabilidade | Proteção |
|----------------|----------|
| SQL Injection | SQLAlchemy ORM (parameterized queries) |
| XSS | React auto-escaping + CSP header |
| CSRF | Token no header Authorization (API REST) |
| Broken Auth | JWT + bcrypt + lockout + rate limiting |
| Sensitive Data | Senhas bcrypt, secrets em env vars |
| Security Headers | CSP, X-Frame-Options, X-XSS-Protection |

### 11.4 Hardening

- Containers rodam como non-root user
- PostgreSQL: usuário sem privilégios de superuser
- Firewall: apenas portas 80/443 (e 22 SSH admin)
- Docker network interna isolada
- Logs sem dados sensíveis (senhas redacted)
- `.env` nunca commitado

---

## 12. Plano de Desenvolvimento MVP

### 12.1 Fase 1 — Fundação & CRUD OFS/OFS (Semanas 1-6)

| Semana | Entregável |
|--------|-----------|
| 1 | Setup: Docker Compose, FastAPI boilerplate, PostgreSQL, Alembic, estrutura de pastas |
| 2 | Modelos: User, Company, OFCRecord. Migrations. Seed de empresas + admin. |
| 3 | Auth: JWT login/refresh/logout, roles, middleware de autorização |
| 4 | CRUD OFS/OFS: create/read/update/cancel com validações e audit |
| 5 | Frontend: Vite + React setup. Login. Layout (AppShell + Sidebar + Header). |
| 6 | Frontend: Formulário de registro OFS. Lista OFCs com paginação. Filtros simples. |

**Checkpoint:** Usuário loga, registra OFS, vê seus registros. Tudo em Docker.

### 12.2 Fase 2 — Consulta & Métricas (Semanas 7-10)

| Semana | Entregável |
|--------|-----------|
| 7 | Backend: Módulo de consulta (filtros dinâmicos). Full-text search. Export CSV. |
| 8 | Frontend: Painel de consulta avançada. Filtros + tabela. |
| 9 | Backend: Módulo de métricas. Cálculo semanal. Indicadores + status. Dashboard API. |
| 10 | Frontend: Dashboard de métricas com Recharts. Todos os gráficos interativos. |

**Checkpoint:** Consulta funcional com todos os filtros. Métricas da semana exibidas.

### 12.3 Fase 3 — Relatórios PDF & Identidade Visual (Semanas 11-14)

| Semana | Entregável |
|--------|-----------|
| 11 | Backend: WeasyPrint + Jinja2 templates. Template HTML corporativo completo. |
| 12 | Backend: chart_service (matplotlib). pdf_service completo. Todos os tipos de relatório. |
| 13 | Frontend: Interface de relatórios. Seletores de tipo/período/empresa. Download. |
| 14 | Testes de PDF com dados reais. Ajustes finos de layout. Histórico de relatórios. |

**Checkpoint:** Gestor/Admin gera PDFs corporativos completos com identidade visual.

### 12.4 Fase 4 — Backup, Admin & Polimentos (Semanas 15-17)

| Semana | Entregável |
|--------|-----------|
| 15 | Backend: Backup automático (APScheduler). Restore. Tela de gestão de backups. |
| 16 | Frontend: Admin panels (usuários, empresas, contratos, metas). Auditoria. |
| 17 | Testes de integração. Documentação final. Deploy scripts. Treinamento. |

**Checkpoint:** Sistema completo. Backup automático. Admin total.

### 12.5 Estimativa de Esforço

| Cenário | Duração |
|---------|---------|
| 2 devs fullstack (1 back + 1 front) | ~17 semanas (4 meses) |
| 1 dev fullstack sozinho | ~24 semanas (6 meses) |
| Time completo (2 back + 2 front + 1 QA) | ~12 semanas (3 meses) |

---

## 13. Riscos Técnicos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|:---:|:---:|-----------|
| WeasyPrint incompatível com CSS complexo | Média | Médio | Templates simples, fallback ReportLab |
| Performance PostgreSQL com >100k registros | Baixa | Alto | Índices, particionamento, VACUUM agressivo |
| Empacotamento offline falho | Média | Alto | Docker multi-stage build, testar em VM sem internet |
| Fontes sem CDN com renderização ruim | Baixa | Baixo | Inter .woff2 local, fallback system-ui |
| JWT secret comprometido | Baixa | Crítico | Env var, rotação programada, audit log |
| Falha no backup automático | Baixa | Crítico | Verificação pós-dump, alerta em tela admin |
| Browser antigo no servidor interno | Média | Médio | Vite build com target es2015, polyfills |
| Migração cloud quebrar paths/volumes | Baixa | Médio | 12-factor app, env vars, volumes como variáveis |

---

## 14. Melhorias Futuras

### 14.1 Curto Prazo (pós-MVP)

- [ ] Certificado HTTPS (CA interna ou autoassinado)
- [ ] Testes automatizados (pytest + React Testing Library)
- [ ] CI/CD com GitHub Actions (self-hosted runner na intranet)
- [ ] Internacionalização (i18n) para espanhol
- [ ] Notificações por email (SMTP interno)
- [ ] Dashboard de KPIs customizável
- [ ] Assinatura digital nos PDFs

### 14.2 Médio Prazo (6-12 meses)

- [ ] Migração para nuvem (AWS/Azure/GCP)
- [ ] PostgreSQL RDS + S3 para PDFs e backups
- [ ] Redis para cache de métricas e sessões
- [ ] Celery/RQ para geração assíncrona de PDFs pesados
- [ ] Read replicas PostgreSQL para consultas
- [ ] Horizontal scaling do backend (2-3 instâncias)
- [ ] CDN interno (Varnish) para assets estáticos

### 14.3 Longo Prazo (12+ meses)

- [ ] Single Sign-On (SSO) com Azure AD / LDAP corporativo
- [ ] Aplicativo mobile nativo (React Native)
- [ ] Modo offline com sincronização (PWA + IndexedDB)
- [ ] Machine Learning: previsão de tendências de segurança
- [ ] Integração com sistemas de RH e operações
- [ ] Extração de microserviços (auth, reports, metrics)
- [ ] Kubernetes + Helm charts
- [ ] Conformidade LGPD e ISO 27001

---

## Checklist de Entrega

- [x] Arquitetura final recomendada
- [x] Stack técnica definida e justificada
- [x] Diagrama lógico dos módulos
- [x] Modelo do banco de dados (10 tabelas, índices, views, funções)
- [x] Fluxo de funcionamento do sistema
- [x] Estrutura das telas (16 rotas, layout, responsividade)
- [x] Regras de negócio (OFS, métricas, validações)
- [x] Regras de acesso (matriz RBAC, data scoping)
- [x] Estrutura dos relatórios e PDF (4 tipos, 8 gráficos, pipeline)
- [x] Estratégia de backup (diário/semanal/mensal, restore, DR)
- [x] Estratégia de segurança (JWT, bcrypt, OWASP, hardening)
- [x] Plano de desenvolvimento MVP (4 fases, 17 semanas)
- [x] Riscos técnicos mapeados
- [x] Melhorias futuras catalogadas

---

**Documento gerado pelo orquestrador de agentes especializados em 13/05/2026.**
