# PLANO DE DESENVOLVIMENTO ORIENTADO POR AGENTES

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Visão Geral dos Agentes](#1-visão-geral-dos-agentes)
2. [Plano por Fases](#2-plano-por-fases)
3. [Backlog Organizado](#3-backlog-organizado)
4. [Sprints Sugeridas](#4-sprints-sugeridas)
5. [Matriz de Responsabilidades](#5-matriz-de-responsabilidades)
6. [Critérios de Aceite](#6-critérios-de-aceite)
7. [Plano de Testes](#7-plano-de-testes)
8. [Riscos e Mitigações](#8-riscos-e-mitigações)
9. [Entregáveis do MVP](#9-entregáveis-do-mvp)
10. [Plano de Evolução Futura](#10-plano-de-evolução-futura)
11. [Recomendações Finais de Execução](#11-recomendações-finais-de-execução)

---

## 1. Visão Geral dos Agentes

### 1.1 Time de Agentes

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ORQUESTRADOR (Você)                               │
│   Coordena, prioriza, resolve conflitos, valida entregas             │
└─────────────────────────────────────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ AGENTE 1        │    │ AGENTE 2        │    │ AGENTE 3        │
│ Product Owner   │    │ Arquiteto       │    │ Backend         │
│ Técnico         │    │ de Software     │    │ Specialist      │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Escopo MVP    │    │ • Stack final   │    │ • APIs REST     │
│ • Prioridades   │    │ • Módulos       │    │ • Regras negócio│
│ • Critérios     │    │ • Offline-first │    │ • JWT + RBAC    │
│ • Backlog       │    │ • Cloud-ready   │    │ • Métricas      │
└─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ AGENTE 4        │    │ AGENTE 5        │    │ AGENTE 6        │
│ Banco de Dados  │    │ Frontend/UX     │    │ Relatórios/PDF  │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Modelo ER     │    │ • Telas (15)    │    │ • Layout PDF    │
│ • Migrations    │    │ • Componentes   │    │ • Templates     │
│ • Índices       │    │ • Responsividade│    │ • Gráficos (img)│
│ • Seeds         │    │ • Fluxos UX     │    │ • Ident. visual │
│ • Otimização    │    │ • Design System │    │ • Geração local │
└─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐
│ AGENTE 7        │    │ AGENTE 8        │
│ DevOps/Infra    │    │ Segurança/Audit │
├─────────────────┤    ├─────────────────┤
│ • Docker Compose│    │ • Política senha│
│ • Nginx config  │    │ • RBAC matrix   │
│ • Volumes       │    │ • Audit logging │
│ • Backup auto   │    │ • Perfil access │
│ • Deploy offline│    │ • OWASP headers │
│ • Checklist     │    │ • Hardening     │
└─────────────────┘    └─────────────────┘
```

### 1.2 Regras de Colaboração

| Regra | Descrição |
|-------|-----------|
| **Orquestrador decide** | Em caso de impasse entre agentes, o orquestrador tem voto final |
| **API-first** | Backend define contrato da API antes do Frontend implementar |
| **Banco primeiro** | Schema do banco é aprovado antes de qualquer código |
| **Critérios antes do código** | Todo épico tem critérios de aceite ANTES de iniciar |
| **Daily sync** | Checkpoint diário entre agentes ativos na sprint |
| **Demo semanal** | Sexta-feira: demo do que foi construído na semana |

---

## 2. Plano por Fases

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  FASE 0  ████  Setup & Validação Técnica           Semana 1-2       │
│  FASE 1  ████  Banco + Backend Base                 Semana 3-4       │
│  FASE 2  ████  Login + Usuários + Permissões        Semana 5-6       │
│  FASE 3  ████  OFS/OFS (CRUD)                      Semana 7-8       │
│  FASE 4  ████  Consulta Individual                  Semana 9          │
│  FASE 5  ████  Métricas da Semana                   Semana 10-11     │
│  FASE 6  ████  Relatórios + PDF + Gráficos          Semana 12-14     │
│  FASE 7  ████  Auditoria + Backup + Deploy          Semana 15-16     │
│  FASE 8  ████  Testes, Ajustes & Homologação         Semana 17-18    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### FASE 0 — Setup & Validação Técnica (Semanas 1-2)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Criar ambiente de desenvolvimento, validar stack, estabelecer padrões |
| **Agentes** | Arquiteto (A2), DevOps (A7), Banco (A4) |
| **Dependências** | Nenhuma |
| **Entregáveis** | Repositório estruturado, Docker Compose funcional, banco rodando, CI básico |

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 0.1 | Criar repositório Git com estrutura de pastas | A2 | 2h |
| 0.2 | Configurar Docker Compose com nginx + backend + db | A7 | 4h |
| 0.3 | Criar Dockerfile backend multi-stage | A7 | 3h |
| 0.4 | Criar Dockerfile frontend (build apenas) | A7 | 1h |
| 0.5 | Configurar nginx.conf (proxy + estáticos + headers) | A7 | 2h |
| 0.6 | Criar estrutura inicial FastAPI (main, config, database) | A2 | 4h |
| 0.7 | Criar estrutura inicial React (Vite + TS + Tailwind + Router) | A5 | 4h |
| 0.8 | Configurar Alembic e criar migration vazia | A4 | 2h |
| 0.9 | Validar comunicação entre containers | A7 | 1h |
| 0.10 | Documentar padrões de código e convenções | A2 | 2h |

**Critérios de Aceite Fase 0:**
- [ ] `docker compose up` sobe 3 containers saudáveis
- [ ] `curl http://localhost:8000/health` retorna 200
- [ ] `http://localhost` carrega página React (vazia)
- [ ] Alembic conecta ao PostgreSQL
- [ ] Estrutura de pastas segue o padrão definido

**Riscos:** Incompatibilidade de versões Docker no servidor de produção  
**Mitigação:** Documentar versão exata do Docker (24+) e testar em VM igual ao servidor

---

### FASE 1 — Banco + Backend Base (Semanas 3-4)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Criar schema completo do banco, migrations, seeds e estrutura base do backend |
| **Agentes** | Banco (A4), Backend (A3) |
| **Dependências** | Fase 0 concluída |
| **Entregáveis** | 11 tabelas criadas, seeds populados, modelos SQLAlchemy, schemas Pydantic |

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 1.1 | Criar migration inicial: todas as 11 tabelas | A4 | 8h |
| 1.2 | Criar triggers (atualizar_em, meta_programada, datas_ofc) | A4 | 3h |
| 1.3 | Criar índices (20+ índices) | A4 | 3h |
| 1.4 | Criar seed migration: 15 empresas + admin | A4 | 2h |
| 1.5 | Criar modelos SQLAlchemy para todas as tabelas | A3 | 8h |
| 1.6 | Criar schemas Pydantic (request/response) | A3 | 6h |
| 1.7 | Criar estrutura de services (vazios, com assinaturas) | A3 | 4h |
| 1.8 | Criar estrutura de routers (vazios, registrados no main) | A3 | 2h |
| 1.9 | Configurar CORS e exception handlers globais | A3 | 2h |
| 1.10 | Testar migrations: `alembic upgrade head` + `downgrade` | A4 | 2h |

**Critérios de Aceite Fase 1:**
- [ ] `alembic upgrade head` cria todas as tabelas sem erros
- [ ] Seeds populam 15 empresas e 1 admin
- [ ] Modelos SQLAlchemy carregam sem erros de importação
- [ ] Swagger UI exibe todos os routers (mesmo vazios)
- [ ] `alembic downgrade base` reverte tudo

**Riscos:** Schema mal dimensionado para crescimento futuro  
**Mitigação:** Revisão do schema pelo Arquiteto (A2) antes do merge

---

### FASE 2 — Login + Usuários + Permissões (Semanas 5-6)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Autenticação completa, CRUD de cadastros básicos, RBAC funcional |
| **Agentes** | Backend (A3), Segurança (A8), Frontend (A5), Banco (A4) |
| **Dependências** | Fase 1 concluída |
| **Entregáveis** | Login funcional, JWT, CRUD de usuários/empresas/contratos/locais, tela de login |

**Backend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 2.1 | Implementar bcrypt + JWT (access/refresh) | A3 | 4h |
| 2.2 | POST /api/auth/login com lockout (5 falhas) | A3 | 4h |
| 2.3 | POST /api/auth/refresh, POST /api/auth/logout | A3 | 3h |
| 2.4 | GET /api/auth/me, PUT /api/auth/change-password | A3 | 2h |
| 2.5 | Middleware de autorização (get_current_user) | A8 | 3h |
| 2.6 | Dependências RBAC: require_role, data_scope | A8 | 4h |
| 2.7 | CRUD /api/usuarios (Admin/Gestor) | A3 | 4h |
| 2.8 | CRUD /api/empresas (Admin) | A3 | 2h |
| 2.9 | CRUD /api/contratos (Admin) | A3 | 2h |
| 2.10 | CRUD /api/locais (Admin) | A3 | 2h |
| 2.11 | Testes unitários de auth e permissões | A3/A8 | 4h |

**Frontend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 2.12 | Tela Login (validação, erro, bloqueio) | A5 | 4h |
| 2.13 | Zustand authStore (token, user, login, logout) | A5 | 3h |
| 2.14 | Axios interceptors (401 → login, 403 → toast) | A5 | 2h |
| 2.15 | AppShell: Header + Sidebar + Outlet | A5 | 4h |
| 2.16 | Sidebar condicional por perfil | A5 | 3h |
| 2.17 | ProtectedRoute com verificação de role | A5 | 2h |
| 2.18 | Tela Admin/Usuarios (tabela + modal CRUD) | A5 | 4h |
| 2.19 | Tela Admin/Empresas (tabela + modal) | A5 | 2h |
| 2.20 | Tela Admin/Contratos (tabela + modal) | A5 | 2h |
| 2.21 | Tela Admin/Locais (tabela + modal) | A5 | 2h |
| 2.22 | Tela Perfil (alterar senha) | A5 | 2h |

**Critérios de Aceite Fase 2:**
- [ ] Login com admin/admin123 funciona
- [ ] Token JWT gerado com 15 minutos de expiração
- [ ] Refresh token renova sem novo login
- [ ] 5 falhas bloqueiam por 30 minutos
- [ ] Observador NÃO vê links de Admin na sidebar
- [ ] Admin vê todos os links
- [ ] CRUD de usuários/empresas/contratos/locais funcional
- [ ] Alterar senha funciona

**Riscos:** JWT secret fraco ou exposto  
**Mitigação:** Secret mínimo 32 caracteres, gerado aleatoriamente, armazenado em .env

---

### FASE 3 — OFS/OFS CRUD (Semanas 7-8)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | CRUD completo de registros OFS/OFS com todas as regras de negócio |
| **Agentes** | Backend (A3), Frontend (A5), Segurança (A8) |
| **Dependências** | Fase 2 concluída |
| **Entregáveis** | Formulário de criação, lista, detalhe, edição, cancelamento, regras de janela |

**Backend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 3.1 | POST /api/OFS — criar registro com validações | A3 | 4h |
| 3.2 | Regra: empresa "Outros" exige custom_company_name | A3 | 2h |
| 3.3 | Preencher snapshots do usuário automaticamente | A3 | 2h |
| 3.4 | GET /api/OFS — listar com paginação + data scoping | A3 | 3h |
| 3.5 | GET /api/OFS/:id — detalhe + histórico de edições | A3 | 2h |
| 3.6 | PUT /api/OFS/:id — editar com regras de janela | A3 | 4h |
| 3.7 | Verificar: Observador 24h, Supervisor 48h, Gestor/Admin sem limite | A8 | 2h |
| 3.8 | Registrar ofc_edicoes (campo, old_value, new_value) | A3 | 2h |
| 3.9 | PATCH /api/OFS/:id/cancelar — soft delete (Gestor/Admin) | A3 | 3h |
| 3.10 | Audit logging em todas as operações OFS | A8 | 2h |
| 3.11 | Testes unitários das regras de negócio OFS | A3 | 4h |

**Frontend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 3.12 | Componentes UI: DatePicker, Textarea, RadioGroup, Badge | A5 | 3h |
| 3.13 | Tela Nova OFS — formulário completo | A5 | 8h |
| 3.14 | Dropdown de empresas com campo condicional "Outros" | A5 | 3h |
| 3.15 | Validação inline (campo obrigatório, mínimo caracteres) | A5 | 3h |
| 3.16 | Tela de Sucesso — nº OFS + ações (ver, PDF, novo) | A5 | 2h |
| 3.17 | Tela Lista OFCs — tabela + paginação + filtros rápidos | A5 | 6h |
| 3.18 | Tela Detalhe OFS — visualização completa + badges | A5 | 4h |
| 3.19 | Tela Editar OFS — formulário pré-preenchido | A5 | 3h |
| 3.20 | Modal de Cancelamento (motivo obrigatório) | A5 | 2h |
| 3.21 | Botões condicionais por permissão (editar, cancelar) | A5 | 2h |

**Critérios de Aceite Fase 3:**
- [ ] Criar OFS com todos os campos preenchidos → sucesso
- [ ] Selecionar "Outros" sem preencher nome → erro de validação
- [ ] Observador vê apenas seus OFCs na lista
- [ ] Supervisor vê OFCs do contrato
- [ ] Admin vê todos
- [ ] Observador edita seu OFS em até 24h → sucesso
- [ ] Observador tenta editar após 24h → erro "janela expirada"
- [ ] Supervisor tenta editar OFS de outro contrato → 403
- [ ] Cancelamento registra motivo e exibe status Cancelado
- [ ] OFS cancelada não aparece em métricas

**Riscos:** Conflito de edição simultânea (2 usuários editam o mesmo OFS)  
**Mitigação:** Optimistic locking (verificar updated_at antes de salvar)

---

### FASE 4 — Consulta Individual (Semana 9)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Consulta avançada com múltiplos filtros e busca textual |
| **Agentes** | Backend (A3), Frontend (A5), Banco (A4) |
| **Dependências** | Fase 3 concluída |
| **Entregáveis** | Tela de consulta com filtros dinâmicos, FTS, paginação |

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 4.1 | Query builder dinâmico (filtros condicionais SQLAlchemy) | A3 | 4h |
| 4.2 | Full-text search (tsvector português) na consulta | A4 | 3h |
| 4.3 | GET /api/consulta — endpoint com 15 parâmetros de filtro | A3 | 3h |
| 4.4 | Paginação e ordenação dinâmica | A3 | 2h |
| 4.5 | Tela Consulta — FilterBar com todos os campos | A5 | 6h |
| 4.6 | Tabela de resultados com ações (ver, editar, cancelar) | A5 | 4h |
| 4.7 | Limpar filtros, feedback de resultados encontrados | A5 | 2h |
| 4.8 | Testar combinações de filtros (AND lógico) | A3/A5 | 2h |

**Critérios de Aceite Fase 4:**
- [ ] Filtrar por data início + data fim → resultados corretos
- [ ] Filtrar por empresa + tipo → interseção correta
- [ ] Busca textual por nome do observado → resultados relevantes
- [ ] Paginação: 25 itens por página
- [ ] "Limpar filtros" reseta tudo
- [ ] Observador vê apenas seus resultados
- [ ] Supervisor vê resultados do contrato

---

### FASE 5 — Métricas da Semana (Semanas 10-11)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Cálculo de métricas semanais, painel de indicadores, status |
| **Agentes** | Backend (A3), Frontend (A5), Banco (A4) |
| **Dependências** | Fase 3 concluída (OFCs existentes) |
| **Entregáveis** | API de métricas, painel com 10 indicadores, status colorido |

**Backend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 5.1 | Criar serviço de métricas: calculate_weekly_metrics() | A3 | 6h |
| 5.2 | Buscar meta vigente (targets) para a semana | A3 | 2h |
| 5.3 | Calcular 10 indicadores (fórmulas já definidas) | A3 | 3h |
| 5.4 | Classificar status (OK/ATENÇÃO/ALERTA) | A3 | 1h |
| 5.5 | GET /api/metricas/semana — endpoint completo | A3 | 2h |
| 5.6 | GET /api/metricas/evolucao — últimas 8 semanas | A3 | 3h |
| 5.7 | GET /api/metricas/ranking-empresas | A3 | 2h |
| 5.8 | GET /api/metricas/ranking-usuarios | A3 | 2h |
| 5.9 | Cache em memória (TTLCache 5 minutos) | A3 | 2h |
| 5.10 | Testes unitários de cálculo de métricas | A3 | 3h |

**Frontend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 5.11 | Componente StatCard (label, valor, ícone, cor) | A5 | 2h |
| 5.12 | Componente StatusBadge (OK/ATENÇÃO/ALERTA) | A5 | 1h |
| 5.13 | Tela Métricas — seletor de semana (setas + date) | A5 | 3h |
| 5.14 | Cards: Aderência, % Seguro, Status (3 principais) | A5 | 3h |
| 5.15 | Cards: 7 indicadores detalhados | A5 | 2h |
| 5.16 | Filtros: contrato, empresa, turno, usuário | A5 | 2h |
| 5.17 | Gráfico Recharts: Programado x Realizado (barras) | A5 | 3h |
| 5.18 | Gráfico Recharts: Positivo x Negativo (donut) | A5 | 2h |
| 5.19 | Gráfico Recharts: OFS por Empresa (barras horiz.) | A5 | 2h |
| 5.20 | Gráfico Recharts: OFS por Usuário (barras) | A5 | 2h |
| 5.21 | Gráfico Recharts: Evolução Semanal (linha) | A5 | 3h |
| 5.22 | Tabela consolidada (empresas/contratos) | A5 | 3h |
| 5.23 | Botão "Exportar PDF" (aciona API de relatórios) | A5 | 1h |

**Critérios de Aceite Fase 5:**
- [ ] OFS Programadas = Pessoas Ativas × Meta por Pessoa (correto)
- [ ] Aderência % = Realizadas ÷ Programadas × 100
- [ ] Status OK (≥100%): verde
- [ ] Status ATENÇÃO (80-99%): amarelo
- [ ] Status ALERTA (<80%): vermelho
- [ ] Navegação entre semanas funciona
- [ ] Filtro por contrato atualiza indicadores
- [ ] 5 gráficos renderizados corretamente
- [ ] Supervisor vê apenas métricas do seu contrato
- [ ] Gestor/Admin veem todas as empresas

**Riscos:** Cálculo incorreto por incluir OFCs canceladas  
**Mitigação:** Filtrar `status_registro != 'Cancelado'` em todas as queries de métricas

---

### FASE 6 — Relatórios + PDF + Gráficos (Semanas 12-14)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Geração de PDFs corporativos com identidade visual, gráficos e templates |
| **Agentes** | Relatórios/PDF (A6), Backend (A3), Frontend (A5) |
| **Dependências** | Fase 3 (OFCs), Fase 5 (métricas) |
| **Entregáveis** | PDF individual, PDF semanal, templates, chart_service, pdf_service |

**Backend/PDF:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 6.1 | Configurar WeasyPrint + fontes Inter locais | A6 | 3h |
| 6.2 | Criar template _base.html (header, footer, @page CSS) | A6 | 4h |
| 6.3 | Criar template individual.html (relatório OFS único) | A6 | 3h |
| 6.4 | Criar template semanal.html (métricas + gráficos) | A6 | 4h |
| 6.5 | Criar chart_service.py — função para cada gráfico | A6 | 8h |
| 6.6 | Gerar PNG com matplotlib → converter para base64 | A6 | 3h |
| 6.7 | Criar pdf_service.py — renderizar Jinja2 + WeasyPrint | A6 | 4h |
| 6.8 | Criar report_service.py — orquestrador | A3 | 4h |
| 6.9 | POST /api/relatorios/gerar — endpoint | A3 | 3h |
| 6.10 | GET /api/relatorios/:id/download — StreamingResponse | A3 | 2h |
| 6.11 | GET /api/relatorios — histórico | A3 | 2h |
| 6.12 | Testar geração de PDF com dados reais | A6/A3 | 4h |

**Frontend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 6.13 | Tela Relatórios — cards com tipos de relatório | A5 | 4h |
| 6.14 | Seletor de parâmetros (semana, mês, contrato, empresa) | A5 | 3h |
| 6.15 | Botão "Gerar PDF" com loading state | A5 | 2h |
| 6.16 | Histórico de relatórios gerados (tabela + download) | A5 | 3h |
| 6.17 | Integração com download automático após geração | A5 | 2h |

**Critérios de Aceite Fase 6:**
- [ ] PDF individual gerado em A4 com logo SD, todos os campos, status
- [ ] PDF semanal gerado com tabela de indicadores + 5 gráficos
- [ ] Cores corporativas aplicadas (vermelho #CC0000, preto, cinza, branco)
- [ ] Rodapé: "Gerado em DD/MM/AAAA HH:MM | Página X/Y"
- [ ] "Documento gerado automaticamente pelo Sistema OFS/OFS"
- [ ] Download funciona com nome correto
- [ ] Geração < 30 segundos para PDF semanal
- [ ] Geração < 5 segundos para PDF individual
- [ ] Gráficos visíveis e proporcionais no PDF
- [ ] Nenhuma dependência externa (tudo local)

**Riscos:** WeasyPrint não encontrar fontes ou logo  
**Mitigação:** Logo em base64 embedado. Fontes em path absoluto no container. Testar em Docker.

---

### FASE 7 — Auditoria + Backup + Deploy Local (Semanas 15-16)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Auditoria completa, backup automático, script de deploy offline, documentação |
| **Agentes** | Segurança (A8), DevOps (A7), Backend (A3) |
| **Dependências** | Todas as fases anteriores |
| **Entregáveis** | Logs de auditoria, backup diário, restore, manual de implantação |

**Backend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 7.1 | Implementar middleware de auditoria (todas as ações) | A8 | 4h |
| 7.2 | GET /api/auditoria — consulta paginada (Admin) | A3 | 3h |
| 7.3 | APScheduler: backup diário 03:00 AM | A7 | 3h |
| 7.4 | Rotação de backups (30 diários, 12 semanais, 12 mensais) | A7 | 2h |
| 7.5 | POST /api/backup/manual | A3 | 2h |
| 7.6 | GET /api/backup/status | A3 | 1h |
| 7.7 | POST /api/backup/:id/restore (com confirmação) | A3 | 3h |

**Frontend:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 7.8 | Tela Auditoria — tabela de logs + filtros | A5 | 4h |
| 7.9 | Tela Admin/Backup — status + histórico + botão manual | A5 | 3h |
| 7.10 | Modal de confirmação para restore | A5 | 2h |

**DevOps/Documentação:**

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 7.11 | Script deploy.sh (deploy automatizado) | A7 | 2h |
| 7.12 | Script backup-manual.sh | A7 | 1h |
| 7.13 | Script restore.sh | A7 | 1h |
| 7.14 | Script health-check.sh | A7 | 1h |
| 7.15 | Manual de implantação (README.md) | A7 | 4h |
| 7.16 | Manual básico do usuário (1 página por perfil) | A1 | 3h |
| 7.17 | Checklist de homologação | A1 | 2h |

**Critérios de Aceite Fase 7:**
- [ ] Todas as ações críticas registradas em auditoria
- [ ] Admin consegue filtrar logs por usuário, ação, período
- [ ] Backup automático executado às 03:00
- [ ] Arquivo .dump gerado com tamanho > 0
- [ ] Rotação remove backups com > 30 dias
- [ ] Backup manual funciona via UI
- [ ] Restore testado em ambiente isolado
- [ ] README.md cobre todos os passos de deploy

---

### FASE 8 — Testes, Ajustes & Homologação (Semanas 17-18)

| Campo | Detalhe |
|-------|---------|
| **Objetivo** | Testes de integração, ajustes finos, homologação completa |
| **Agentes** | TODOS |
| **Dependências** | Fases 0-7 concluídas |
| **Entregáveis** | Sistema homologado, bugs corrigidos, deploy produção |

| # | Tarefa | Agente | Esforço |
|---|--------|--------|:---:|
| 8.1 | Teste de fluxo completo por perfil | A1/A5/A3 | 8h |
| 8.2 | Teste de responsividade (desktop, tablet, mobile) | A5 | 4h |
| 8.3 | Teste de regras de negócio (janela edição, permissões) | A3/A8 | 4h |
| 8.4 | Teste de métricas com dados reais (planilha de validação) | A3 | 4h |
| 8.5 | Teste de geração de PDF em lote (10 PDFs simultâneos) | A6 | 3h |
| 8.6 | Teste de backup e restore (ambiente isolado) | A7 | 3h |
| 8.7 | Teste de deploy offline (simular servidor sem internet) | A7 | 4h |
| 8.8 | Correção de bugs encontrados | Todos | 12h |
| 8.9 | Ajustes finos de CSS e UX | A5 | 6h |
| 8.10 | Build de produção final | A7 | 2h |
| 8.11 | Homologação formal com checklist | A1 | 4h |
| 8.12 | Deploy no servidor de produção | A7 | 4h |
| 8.13 | Treinamento básico (30 min por perfil) | A1 | 2h |

**Critérios de Aceite Fase 8:**
- [ ] Checklist de homologação 100% aprovado
- [ ] Zero bugs críticos
- [ ] Sistema rodando em servidor interno sem internet
- [ ] Todos os 31 critérios de aceite do MVP atendidos (seção 6)

---

## 3. Backlog Organizado

### 3.1 Épicos e Histórias

```
MVP ─── 8 Épicos ─── 34 Histórias ─── 120+ Tarefas


ÉPICO 1: AUTENTICAÇÃO E PERFIS (Fase 2)
├── H1.1: Login com credenciais
│   ├── T: Criar endpoint POST /auth/login
│   ├── T: Implementar bcrypt verify
│   ├── T: Implementar JWT access + refresh token
│   ├── T: Criar tela de login
│   └── T: Lockout após 5 falhas
├── H1.2: Controle de sessão
│   ├── T: Refresh token endpoint
│   ├── T: Logout com revogação
│   └── T: Interceptor 401 no frontend
├── H1.3: Perfis de acesso (RBAC)
│   ├── T: Enum UserRole (Observador, Supervisor, Gestor, Admin)
│   ├── T: Decorator require_role()
│   ├── T: Data scoping por perfil
│   └── T: Sidebar condicional
└── H1.4: CRUD de usuários
    ├── T: CRUD /api/usuarios (Admin)
    ├── T: Ativar/desativar usuário
    └── T: Tela Admin/Usuarios

ÉPICO 2: CADASTROS BÁSICOS (Fase 2)
├── H2.1: Empresas
│   ├── T: CRUD /api/empresas
│   ├── T: Seed 15 empresas
│   └── T: Tela Admin/Empresas
├── H2.2: Contratos
│   ├── T: CRUD /api/contratos
│   └── T: Tela Admin/Contratos
├── H2.3: Locais
│   ├── T: CRUD /api/locais
│   └── T: Tela Admin/Locais
└── H2.4: Metas Semanais
    ├── T: CRUD /api/metas-semanais
    ├── T: Trigger meta_ofc_programada
    ├── T: GET /api/metas-semanais/vigente
    └── T: Tela Admin/Metas

ÉPICO 3: OFS/OFS — CRUD (Fase 3)
├── H3.1: Criar registro OFS/OFS
│   ├── T: POST /api/OFS com validações
│   ├── T: Preencher snapshots do usuário
│   ├── T: Regra "Outros" → campo obrigatório
│   ├── T: Trigger data/semana/mês/ano
│   └── T: Tela Nova OFS
├── H3.2: Listar registros
│   ├── T: GET /api/OFS com data scoping
│   ├── T: Paginação
│   └── T: Tela Lista OFCs
├── H3.3: Visualizar registro
│   ├── T: GET /api/OFS/:id + edições
│   └── T: Tela Detalhe OFS
├── H3.4: Editar registro
│   ├── T: PUT /api/OFS/:id com regras de janela
│   ├── T: Registrar ofc_edicoes
│   └── T: Tela Editar OFS
└── H3.5: Cancelar registro
    ├── T: PATCH /api/OFS/:id/cancelar
    ├── T: Soft delete + motivo obrigatório
    └── T: Modal de cancelamento

ÉPICO 4: CONSULTA (Fase 4)
├── H4.1: Consulta com filtros
│   ├── T: Query builder dinâmico
│   └── T: GET /api/consulta
└── H4.2: Interface de consulta
    ├── T: FilterBar com todos os campos
    ├── T: Tabela de resultados
    └── T: Limpar filtros

ÉPICO 5: MÉTRICAS (Fase 5)
├── H5.1: Cálculo de métricas semanais
│   ├── T: metrics_service.calculate_weekly_metrics()
│   └── T: GET /api/metricas/semana
├── H5.2: Painel de indicadores
│   ├── T: Cards de indicadores
│   ├── T: Status colorido
│   └── T: Tela Métricas
├── H5.3: Gráficos interativos
│   ├── T: 5 gráficos Recharts
│   └── T: Dados via /api/metricas/charts/*
└── H5.4: Evolução e rankings
    ├── T: GET /api/metricas/evolucao
    ├── T: GET /api/metricas/ranking-empresas
    └── T: GET /api/metricas/ranking-usuarios

ÉPICO 6: RELATÓRIOS PDF (Fase 6)
├── H6.1: Infraestrutura de PDF
│   ├── T: Configurar WeasyPrint
│   ├── T: Template _base.html
│   └── T: pdf_service.py
├── H6.2: PDF Individual
│   ├── T: Template individual.html
│   └── T: Geração via API
├── H6.3: PDF Semanal
│   ├── T: Template semanal.html
│   ├── T: chart_service.py (matplotlib)
│   └── T: Geração com gráficos embedados
└── H6.4: Interface de relatórios
    ├── T: Tela Relatórios
    └── T: Histórico + download

ÉPICO 7: AUDITORIA E BACKUP (Fase 7)
├── H7.1: Auditoria
│   ├── T: Middleware de auditoria
│   ├── T: GET /api/auditoria
│   └── T: Tela Auditoria
└── H7.2: Backup
    ├── T: APScheduler backup diário
    ├── T: Rotação de backups
    ├── T: Backup manual + restore
    └── T: Tela Admin/Backup

ÉPICO 8: DEPLOY E HOMOLOGAÇÃO (Fase 7-8)
├── H8.1: Deploy offline
│   ├── T: Scripts de deploy
│   ├── T: Manual de implantação
│   └── T: Teste em servidor sem internet
└── H8.2: Homologação
    ├── T: Checklist de homologação
    ├── T: Testes de integração
    └── T: Treinamento
```

---

## 4. Sprints Sugeridas

### 4.1 Calendário de Sprints (2 semanas cada)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  SPRINT 0  ██  Setup (Semanas 1-2)                                   │
│  ├── Fase 0: Ambiente, Docker, Estrutura                             │
│  └── Demo: docker compose up funcional                               │
│                                                                      │
│  SPRINT 1  ██  Fundação (Semanas 3-6)                                │
│  ├── Fase 1: Banco completo + Models                                 │
│  ├── Fase 2: Auth + Cadastros + RBAC                                 │
│  └── Demo: Login funcional, CRUD de cadastros                        │
│                                                                      │
│  SPRINT 2  ██  Core (Semanas 7-10)                                   │
│  ├── Fase 3: OFS/OFS CRUD completo                                   │
│  ├── Fase 4: Consulta avançada                                       │
│  └── Demo: Criar OFS, consultar, editar, cancelar                    │
│                                                                      │
│  SPRINT 3  ██  Analytics (Semanas 11-14)                             │
│  ├── Fase 5: Métricas + Gráficos interativos                         │
│  ├── Fase 6: PDFs + Templates + Gráficos matplotlib                  │
│  └── Demo: Dashboard métricas + PDF semanal                          │
│                                                                      │
│  SPRINT 4  ██  Produção (Semanas 15-18)                              │
│  ├── Fase 7: Auditoria + Backup + Deploy                             │
│  ├── Fase 8: Testes + Ajustes + Homologação                          │
│  └── Demo: Sistema completo homologado                               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Detalhamento por Sprint

#### SPRINT 0 — Setup (Semanas 1-2)

| Papel | Responsável | Foco |
|-------|------------|------|
| Arquiteto (A2) | Estrutura de pastas, padrões de código | Organização |
| DevOps (A7) | Docker, Nginx, volumes, healthcheck | Ambiente |
| Banco (A4) | Alembic init, migration vazia | Preparação |
| Frontend (A5) | Vite + React + Tailwind setup | Fundação |

**Entregáveis:** docker-compose.yml funcional, estrutura de pastas, hello world em cada camada  
**Risco:** Configuração Docker complexa demais → Manter docker-compose.yml simples (3 serviços)

#### SPRINT 1 — Fundação (Semanas 3-6)

| Papel | Responsável | Semana 3-4 | Semana 5-6 |
|-------|------------|-----------|-----------|
| Banco (A4) | 11 tabelas + índices + seeds + triggers | Foco total | Suporte |
| Backend (A3) | Models SQLAlchemy + Schemas Pydantic | Auth JWT + CRUD endpoints |
| Segurança (A8) | Revisar schema (segurança) | RBAC + lockout + data scoping |
| Frontend (A5) | Estrutura AppShell + Sidebar + Header | Login + Admin CRUDs |

**Entregáveis:** Banco completo, login funcional, CRUD de cadastros, RBAC funcional  
**Demo:** Login como admin → cadastrar usuário → login como observador → sidebar adaptada

#### SPRINT 2 — Core (Semanas 7-10)

| Papel | Responsável | Semana 7-8 | Semana 9-10 |
|-------|------------|-----------|-----------|
| Backend (A3) | CRUD OFS + regras negócio | Consulta + FTS |
| Banco (A4) | Índices FTS, otimização queries | Suporte |
| Frontend (A5) | Nova OFS + Lista + Detalhe + Editar | Consulta avançada |
| Segurança (A8) | Validar regras de edição e cancelamento | Validar data scoping |

**Entregáveis:** OFS funcional, consulta com filtros, regras de janela funcionando  
**Demo:** Criar OFS → consultar → editar (antes e depois de 24h) → cancelar

#### SPRINT 3 — Analytics (Semanas 11-14)

| Papel | Responsável | Semana 11-12 | Semana 13-14 |
|-------|------------|-------------|-------------|
| Backend (A3) | Métricas API + cache | Integração com report_service |
| Relatórios (A6) | WeasyPrint setup + _base.html | Templates + chart_service (matplotlib) |
| Frontend (A5) | Painel métricas + 5 gráficos Recharts | Tela Relatórios + download |
| Banco (A4) | Otimizar queries de métricas | Suporte |

**Entregáveis:** Dashboard de métricas, PDF individual, PDF semanal  
**Demo:** Ver métricas → gerar PDF semanal → baixar e abrir

#### SPRINT 4 — Produção (Semanas 15-18)

| Papel | Responsável | Semana 15-16 | Semana 17-18 |
|-------|------------|-------------|-------------|
| Backend (A3) | Auditoria API + backup API | Correções de bugs |
| DevOps (A7) | Scripts deploy, backup, restore | Deploy produção + validação |
| Segurança (A8) | Middleware auditoria + validação final | Verificação de segurança |
| Frontend (A5) | Telas Auditoria + Backup | Ajustes finos de UX |
| PO (A1) | Checklist homologação | Homologação + treinamento |

**Entregáveis:** Sistema completo homologado em produção  
**Demo:** Sistema rodando no servidor interno, todos os fluxos funcionando

---

## 5. Matriz de Responsabilidades

### 5.1 Responsável Principal por Módulo

```
┌──────────────────────────┬────────────┬──────────────┬──────────────┐
│ MÓDULO                   │ RESPONSÁVEL│ APOIO        │ ENTREGÁVEL   │
├──────────────────────────┼────────────┼──────────────┼──────────────┤
│ Estrutura do Projeto     │ A2         │ A7           │ Pastas, config│
│ Docker / Deploy          │ A7         │ A2           │ docker-compose│
│ Banco de Dados           │ A4         │ A3           │ SQL + migrations│
│ Modelos ORM              │ A3         │ A4           │ models/*.py  │
│ Autenticação (JWT)       │ A3         │ A8           │ auth endpoints│
│ RBAC / Permissões        │ A8         │ A3           │ permissions.py│
│ OFS/OFS CRUD             │ A3         │ A8, A5       │ OFS endpoints│
│ Consulta                 │ A3         │ A4, A5       │ consulta API │
│ Métricas                 │ A3         │ A4, A5       │ metrics API  │
│ Gráficos Frontend        │ A5         │ A3           │ Recharts     │
│ Gráficos PDF             │ A6         │ A3           │ matplotlib   │
│ Templates PDF            │ A6         │ A3           │ Jinja2 HTML  │
│ Geração PDF              │ A6         │ A3           │ WeasyPrint   │
│ Auditoria                │ A8         │ A3           │ audit logs   │
│ Backup                   │ A7         │ A3           │ APScheduler  │
│ Formulário Nova OFS      │ A5         │ A3           │ NovoOFCPage  │
│ Tela Consulta            │ A5         │ A3           │ ConsultaPage │
│ Tela Métricas            │ A5         │ A3           │ MetricasPage │
│ Tela Relatórios          │ A5         │ A6           │ RelatoriosPage│
│ Telas Admin              │ A5         │ A3           │ Admin pages  │
│ Responsividade           │ A5         │ —            │ CSS/Tailwind │
│ Design System            │ A5         │ —            │ tokens/cores │
│ Manual Implantação       │ A7         │ A1           │ README.md    │
│ Homologação              │ A1         │ Todos        │ Checklist    │
└──────────────────────────┴────────────┴──────────────┴──────────────┘
```

### 5.2 Pontos de Integração entre Agentes

```
A3 (Backend) ←→ A5 (Frontend): Contrato da API documentado no Swagger
A3 (Backend) ←→ A4 (Banco):    Models SQLAlchemy refletem schema
A3 (Backend) ←→ A6 (PDF):      Dados via dict Python → Jinja2 template
A3 (Backend) ←→ A8 (Segurança): Dependências RBAC injetadas nos endpoints
A7 (DevOps)  ←→ Todos:         docker-compose.yml integra todos serviços
A1 (PO)      ←→ Todos:         Critérios de aceite, priorização, backlog
```

---

## 6. Critérios de Aceite

### 6.1 Critérios de Aceite do MVP (31 checkpoints)

#### LOGIN E AUTENTICAÇÃO

- [ ] **CA-01**: Usuário faz login com username e senha
- [ ] **CA-02**: Token JWT expira em 15 minutos
- [ ] **CA-03**: Refresh token renova acesso sem novo login
- [ ] **CA-04**: Logout revoga refresh token
- [ ] **CA-05**: 5 tentativas falhas bloqueiam por 30 minutos
- [ ] **CA-06**: Senha armazenada como bcrypt (nunca plain text)

#### PERFIS E PERMISSÕES

- [ ] **CA-07**: Observador vê apenas seus OFCs
- [ ] **CA-08**: Supervisor vê OFCs do contrato
- [ ] **CA-09**: Gestor vê todos os OFCs e pode cancelar
- [ ] **CA-10**: Admin tem acesso total ao sistema
- [ ] **CA-11**: Sidebar adapta links por perfil

#### REGISTRO OFS/OFS

- [ ] **CA-12**: Formulário preenche data/hora/usuário automaticamente
- [ ] **CA-13**: Dropdown de empresas contém 15 empresas + "Outros"
- [ ] **CA-14**: Selecionar "Outros" exige nome da empresa (obrigatório)
- [ ] **CA-15**: Tipo validado: apenas Positivo ou Negativo
- [ ] **CA-16**: Registro salvo com status "Gerado" e nº sequencial
- [ ] **CA-17**: Observador edita seu OFS em até 24h
- [ ] **CA-18**: Supervisor edita OFS do contrato em até 48h
- [ ] **CA-19**: Cancelamento exige motivo (apenas Gestor/Admin)

#### CONSULTA

- [ ] **CA-20**: Filtros combinados funcionam (AND lógico)
- [ ] **CA-21**: Resultados paginados (25 por página)
- [ ] **CA-22**: Busca textual por nome do observado funciona

#### MÉTRICAS

- [ ] **CA-23**: OFS Programadas = Pessoas Ativas × Meta por Pessoa
- [ ] **CA-24**: Aderência calculada corretamente
- [ ] **CA-25**: Status OK (≥100%), ATENÇÃO (80-99%), ALERTA (<80%)
- [ ] **CA-26**: Navegação entre semanas funciona

#### PDF

- [ ] **CA-27**: PDF individual contém todos os campos + logo SD + rodapé
- [ ] **CA-28**: PDF semanal contém indicadores + 5 gráficos + tabela
- [ ] **CA-29**: Cores corporativas aplicadas nos PDFs

#### AUDITORIA E BACKUP

- [ ] **CA-30**: Ações críticas registradas em auditoria
- [ ] **CA-31**: Backup automático diário funcional

---

## 7. Plano de Testes

### 7.1 Testes por Categoria

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PLANO DE TESTES                               │
│                                                                      │
│  TESTES DE AUTENTICAÇÃO                                              │
│  ├── Login com credenciais válidas                                   │
│  ├── Login com credenciais inválidas                                 │
│  ├── Login com usuário inativo                                       │
│  ├── Bloqueio após 5 tentativas                                      │
│  ├── Refresh token renova acesso                                     │
│  ├── Logout revoga refresh token                                     │
│  ├── Acesso a rota protegida sem token → 401                         │
│  └── Token expirado → 401                                           │
│                                                                      │
│  TESTES DE PERMISSÃO (RBAC)                                          │
│  ├── Observador tenta ver OFS de outro → lista vazia ou 403          │
│  ├── Supervisor tenta ver OFS de outro contrato → vazio              │
│  ├── Observador tenta acessar /admin → 403 ou sidebar sem link       │
│  ├── Supervisor tenta cancelar OFS → 403                             │
│  ├── Gestor tenta acessar auditoria → 403                            │
│  └── Admin acessa tudo → 200 em todas as rotas                       │
│                                                                      │
│  TESTES DE OFS/OFS                                                   │
│  ├── Criar OFS com todos os campos → 201                             │
│  ├── Criar OFS sem campos obrigatórios → 422                         │
│  ├── Criar OFS com "Outros" sem nome → 422                           │
│  ├── Criar OFS com data futura → 422                                 │
│  ├── Editar OFS próprio em < 24h → 200                               │
│  ├── Editar OFS próprio em > 24h (Observador) → 409                  │
│  ├── Editar OFS do contrato em < 48h (Supervisor) → 200              │
│  ├── Editar OFS do contrato em > 48h (Supervisor) → 409              │
│  ├── Editar OFS de outro contrato (Supervisor) → 403                 │
│  ├── Cancelar OFS como Gestor → 200, status Cancelado                │
│  ├── Cancelar OFS como Observador → 403                              │
│  ├── Cancelar OFS sem motivo → 422                                   │
│  └── OFS cancelada não aparece em métricas                           │
│                                                                      │
│  TESTES DE CONSULTA                                                  │
│  ├── Filtrar por data (início + fim)                                 │
│  ├── Filtrar por empresa                                             │
│  ├── Filtrar por tipo (Positivo/Negativo)                            │
│  ├── Filtrar por turno                                               │
│  ├── Filtrar por status                                              │
│  ├── Combinar 3+ filtros                                             │
│  ├── Busca textual retorna resultados relevantes                     │
│  └── Paginação funciona (página 1, 2, última)                        │
│                                                                      │
│  TESTES DE MÉTRICAS                                                  │
│  ├── Cálculo manual vs sistema (planilha de validação)               │
│  ├── Semana sem registros → indicadores zero                         │
│  ├── Semana sem meta → mensagem "sem meta cadastrada"                │
│  ├── Status OK com 100% de aderência                                 │
│  ├── Status ATENÇÃO com 85% de aderência                             │
│  ├── Status ALERTA com 70% de aderência                              │
│  ├── Navegação entre semanas                                         │
│  └── Filtro por contrato altera indicadores                          │
│                                                                      │
│  TESTES DE PDF                                                       │
│  ├── PDF individual gerado corretamente                              │
│  ├── Logo SD visível no cabeçalho                                    │
│  ├── Rodapé com data e página                                        │
│  ├── PDF semanal com tabela e 5 gráficos                             │
│  ├── Download funciona                                                │
│  ├── PDF abre em Adobe Acrobat                                       │
│  ├── PDF abre em Chrome PDF Viewer                                   │
│  └── Impressão fiel ao visualizado                                   │
│                                                                      │
│  TESTES DE BACKUP                                                     │
│  ├── Backup automático executa às 03:00                              │
│  ├── Arquivo .dump gerado > 0 bytes                                  │
│  ├── Restore em banco vazio → dados restaurados                      │
│  ├── Rotação remove backups > 30 dias                                │
│  └── Backup manual via UI funciona                                   │
│                                                                      │
│  TESTES DE AMBIENTE OFFLINE                                           │
│  ├── Desconectar internet → sistema funciona                         │
│  ├── Fontes carregam localmente (sem Google Fonts)                   │
│  ├── Ícones carregam localmente (sem CDN)                             │
│  ├── PDF gera sem internet                                           │
│  └── Gráficos renderizam sem internet                                │
│                                                                      │
│  TESTES DE RESPONSIVIDADE                                            │
│  ├── Desktop 1920px → sidebar visível, tabelas completas             │
│  ├── Tablet 768px → sidebar colapsável, cards 2 colunas              │
│  └── Mobile 375px → formulários 1 coluna, cards empilhados           │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.2 Massa de Dados para Testes

```
┌─────────────────────────────────────────────────────────────────────┐
│  DADOS DE TESTE (Semente)                                            │
│                                                                      │
│  Empresas:      15 (seed) + 2 customizadas                           │
│  Usuários:      1 Admin + 2 Gestores + 3 Supervisores + 5 Observad.  │
│  Contratos:     3 (Operação SD, G4S, ERA)                            │
│  Locais:        5 por contrato (15 total)                             │
│  Metas:         4 semanas configuradas por contrato                   │
│  OFCs:          200 registros de teste (mix Positivo/Negativo,        │
│                 distribuídos em 4 semanas, vários turnos)             │
│                                                                      │
│  Distribuição esperada nos 200 OFCs:                                  │
│  ├── Semana 18: 50 OFCs (35 positivos, 15 negativos)                 │
│  ├── Semana 19: 45 OFCs (32 positivos, 13 negativos)                 │
│  ├── Semana 20: 55 OFCs (42 positivos, 13 negativos)                 │
│  └── Semana 21: 50 OFCs (38 positivos, 12 negativos)                 │
│                                                                      │
│  Isso permite testar:                                                 │
│  - Métricas com dados reais                                          │
│  - Evolução semanal (4 pontos)                                       │
│  - Rankings                                                            │
│  - PDF semanal com dados visíveis                                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Riscos e Mitigações

```
┌────┬──────────────────────────────────┬────────┬────────────────────────────────────┐
│  # │ RISCO                             │ IMPACTO│ MITIGAÇÃO                           │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R1 │ Dependência externa acidental     │ ALTO   │ Testar em VM sem internet antes     │
│    │ (import esquece de usar CDN,      │        │ de cada release. Script de          │
│    │ Google Fonts, API externa)        │        │ verificação de imports.             │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R2 │ PDF desalinhado ou com fontes     │ MÉDIO  │ Testar com WeasyPrint em Docker.    │
│    │ faltantes                         │        │ Usar logo em base64. Fontes em      │
│    │                                   │        │ path absoluto no container.         │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R3 │ Falha de backup automático        │ CRÍTICO│ Verificação de integridade pós-     │
│    │ (pg_dump silencioso)              │        │ dump. Alerta visível no dashboard   │
│    │                                   │        │ admin. Teste de restore mensal.     │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R4 │ Lentidão em consultas com muitos  │ MÉDIO  │ Índices cobrem todos os filtros.    │
│    │ registros (>50k)                  │        │ Paginação server-side. FTS com GIN. │
│    │                                   │        │ Plano de particionamento (Fase 2).  │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R5 │ Erro no cálculo semanal           │ ALTO   │ Validar fórmula com planilha.       │
│    │ (OFCs canceladas incluídas,       │        │ Testes unitários com massa conhecida│
│    │  meta errada, divisão por zero)   │        │ Tratar divisão por zero (NULLIF).   │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R6 │ Acesso indevido por perfil        │ CRÍTICO│ Testes automatizados de RBAC.       │
│    │ (Observador vê dados de outro)    │        │ Data scoping em TODAS as queries.   │
│    │                                   │        │ Revisão de código por segurança.    │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R7 │ Perda de dados por restore não    │ CRÍTICO│ Teste de restore mensal em ambiente │
│    │ testado                           │        │ isolado. Documentar procedimento.   │
│    │                                   │        │ Script restore.sh com confirmação.  │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R8 │ Incompatibilidade Docker no       │ MÉDIO  │ Documentar versão exata (24+).       │
│    │ servidor de produção              │        │ Testar em VM com mesmo SO do servidor│
│    │                                   │        │ Fornecer instruções de instalação.  │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R9 │ Timeout na geração de PDF com     │ BAIXO  │ Async generation. Timeout 60s.       │
│    │ muitos dados                      │        │ Limitar dados no PDF. Cache gráficos │
├────┼──────────────────────────────────┼────────┼────────────────────────────────────┤
│ R10│ JWT secret fraco ou exposto       │ CRÍTICO│ Gerar secret aleatório (32+ chars).  │
│    │                                   │        │ Armazenar APENAS em .env.           │
│    │                                   │        │ .env no .gitignore.                 │
└────┴──────────────────────────────────┴────────┴────────────────────────────────────┘
```

---

## 9. Entregáveis do MVP

### 9.1 Checklist de Entregáveis

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ENTREGÁVEIS DO MVP                                │
│                                                                      │
│  CÓDIGO                                                              │
│  ☐ Repositório Git com código fonte                                  │
│  ☐ Frontend: React + Vite + TypeScript + Tailwind                    │
│  ☐ Backend: FastAPI + SQLAlchemy + Alembic                           │
│  ☐ Docker Compose (3 serviços: nginx, backend, db)                   │
│  ☐ Dockerfiles (backend multi-stage, nginx)                          │
│                                                                      │
│  BANCO DE DADOS                                                      │
│  ☐ 11 tabelas com PKs, FKs, CHECKs, índices                         │
│  ☐ Migrations Alembic (upgrade/downgrade funcionais)                 │
│  ☐ Seeds: 15 empresas + admin                                        │
│  ☐ Triggers automáticos (datas, meta_programada, atualizado_em)      │
│                                                                      │
│  APLICAÇÃO                                                           │
│  ☐ 15 telas funcionais                                               │
│  ☐ 45+ endpoints REST                                                │
│  ☐ Autenticação JWT + RBAC 4 perfis                                  │
│  ☐ CRUD OFS/OFS com regras de negócio                               │
│  ☐ Consulta com 15 parâmetros de filtro + FTS                        │
│  ☐ Métricas semanais (10 indicadores + status)                       │
│  ☐ 5 gráficos interativos (Recharts)                                 │
│                                                                      │
│  RELATÓRIOS PDF                                                      │
│  ☐ Template base (_base.html) com identidade visual                  │
│  ☐ PDF individual de OFS                                             │
│  ☐ PDF MÉTRICAS DA SEMANA (indicadores + 5 gráficos)                 │
│  ☐ chart_service.py (matplotlib PNG → base64)                        │
│  ☐ pdf_service.py (Jinja2 + WeasyPrint)                              │
│                                                                      │
│  AUDITORIA E BACKUP                                                  │
│  ☐ Logs de auditoria para todas as ações críticas                    │
│  ☐ Tela de consulta de auditoria (Admin)                             │
│  ☐ Backup automático diário (APScheduler)                            │
│  ☐ Rotação de backups (30 dias)                                      │
│  ☐ Backup manual + restore (Admin)                                   │
│                                                                      │
│  SCRIPTS E DOCUMENTAÇÃO                                              │
│  ☐ deploy.sh                                                         │
│  ☐ backup-manual.sh                                                  │
│  ☐ restore.sh                                                        │
│  ☐ health-check.sh                                                   │
│  ☐ rotate-logs.sh                                                    │
│  ☐ README.md (manual de implantação)                                 │
│  ☐ Manual do usuário (1 página por perfil)                           │
│  ☐ Checklist de homologação                                          │
│                                                                      │
│  DESIGN                                                              │
│  ☐ Design System documentado (cores, fontes, espaçamento, ícones)    │
│  ☐ Logo Security Dynamics (PNG + SVG)                                │
│  ☐ Fontes Inter (.woff2) locais                                      │
│  ☐ Wireframes de todas as telas                                      │
│                                                                      │
│  DOCUMENTAÇÃO TÉCNICA (já produzida)                                 │
│  ☐ PLANO_MESTRE_SISTEMA_OFS.md                                       │
│  ☐ PLANO_TECNICO_MVP_OFS.md                                          │
│  ☐ MODELAGEM_TECNICA_BD_API_MVP.md                                   │
│  ☐ ESPECIFICACAO_UX_UI_MVP.md                                        │
│  ☐ ESPECIFICACAO_RELATORIOS_PDF_MVP.md                               │
│  ☐ ARQUITETURA_INFRA_DEPLOY_SEGURANCA.md                             │
│  ☐ PLANO_DESENVOLVIMENTO_AGENTES.md (este documento)                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. Plano de Evolução Futura

### 10.1 Roadmap Pós-MVP

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  MVP (Mês 1-4)                                                       │
│  ████████████████████████████████████████████████                    │
│  Login + OFS + Consulta + Métricas + PDF + Auditoria + Backup        │
│                                                                      │
│  v1.1 (Mês 5-6) — Refinamentos Operacionais                          │
│  ├── Exportar CSV da consulta                                        │
│  ├── Dashboard principal com cards de resumo                         │
│  ├── Botão "Salvar e Novo" (registro em lote)                        │
│  ├── Relatório mensal completo                                       │
│  ├── Top comportamentos no PDF                                       │
│  └── Melhorias de UX baseadas em feedback                            │
│                                                                      │
│  v1.2 (Mês 7-8) — Funcionalidades Avançadas                          │
│  ├── Anexos/fotos no OFS/OFS (upload local)                          │
│  ├── Dashboard de KPIs customizável                                  │
│  ├── Alertas de meta (notificação interna)                           │
│  ├── Exportação Excel avançada                                       │
│  └── Relatório de tendências preditivas                              │
│                                                                      │
│  v1.3 (Mês 9-10) — Escala e Segurança                                │
│  ├── HTTPS com certificado interno                                   │
│  ├── Redis para cache de métricas                                    │
│  ├── Geração assíncrona de PDFs (fila)                               │
│  ├── Particionamento do banco (ofc_records por mês)                  │
│  └── Testes automatizados (pytest + React Testing Library)           │
│                                                                      │
│  v2.0 (Mês 11-14) — Cloud e Expansão                                 │
│  ├── Migração para cloud (AWS/Azure/GCP)                             │
│  ├── PostgreSQL RDS + S3 para PDFs                                   │
│  ├── CI/CD pipeline (GitHub Actions)                                 │
│  ├── Infraestrutura como código (Terraform)                          │
│  ├── Kubernetes (EKS/AKS/GKE)                                        │
│  └── Single Sign-On (SSO) com Azure AD / LDAP                        │
│                                                                      │
│  v2.1+ (Mês 15+) — Inovação                                          │
│  ├── Aplicativo mobile (React Native / PWA)                          │
│  ├── Machine Learning: previsão de comportamentos de risco           │
│  ├── Integração com sistemas de RH                                   │
│  ├── API externa para sistemas parceiros                             │
│  ├── Conformidade LGPD e ISO 27001                                   │
│  └── Business Intelligence (Metabase / Power BI)                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 11. Recomendações Finais de Execução

### 11.1 Regras de Ouro

| # | Regra | Motivo |
|---|-------|--------|
| 1 | **API-first** — Backend entrega contrato antes do Frontend começar | Evita retrabalho de integração |
| 2 | **Banco aprovado antes do código** — Schema revisado e migrado antes de escrever services | Evita refatoração de modelos |
| 3 | **Uma tela por vez** — Não começar outra até a atual estar funcional | Foco, entregas parciais |
| 4 | **Commits pequenos e frequentes** — Mínimo 1 commit por tarefa concluída | Rastreabilidade, rollback fácil |
| 5 | **Demo toda sexta-feira** — Mostrar o que funciona, não o que está "quase" | Feedback rápido, visibilidade |
| 6 | **Nunca pular testes de permissão** — Todo endpoint testado com 4 perfis | Segurança é requisito, não feature |
| 7 | **Sempre testar offline** — Desconectar internet antes de validar qualquer build | Premissa fundamental do sistema |
| 8 | **Documentar enquanto codifica** — README, docstrings, comentários de decisão | Manutenção futura |

### 11.2 Ordem de Execução Recomendada

```
1. AMBIENTE (Sprint 0)
   └── Sem ambiente funcional, nada acontece. Prioridade máxima.

2. BANCO (Início Sprint 1)
   └── Schema define tudo. Migration primeiro, código depois.

3. AUTH (Meio Sprint 1)
   └── Sem login, nada é testável. JWT + RBAC cedo.

4. CADASTROS (Final Sprint 1)
   └── Admin precisa cadastrar antes dos operadores usarem.

5. OFS CRUD (Sprint 2)
   └── CORAÇÃO do sistema. Onde o valor é entregue.

6. CONSULTA (Final Sprint 2)
   └── Depende de OFCs existentes para ter o que consultar.

7. MÉTRICAS (Início Sprint 3)
   └── Depende de OFCs e metas cadastradas.

8. PDF + GRÁFICOS (Sprint 3)
   └── Depende de métricas e OFCs. Parte mais complexa tecnicamente.

9. AUDITORIA + BACKUP (Sprint 4)
   └── Transversal. Pode ser feito em paralelo, mas antes da homologação.

10. HOMOLOGAÇÃO (Final Sprint 4)
    └── Só depois de tudo funcionando.
```

### 11.3 Comunicação entre Agentes

```
┌─────────────────────────────────────────────────────────────────────┐
│  CANAIS DE COMUNICAÇÃO                                               │
│                                                                      │
│  Diário (15 min):                                                    │
│  └── O que fez ontem? O que vai fazer hoje? Algum bloqueio?          │
│                                                                      │
│  Semanal (30 min, sexta-feira):                                      │
│  └── Demo do que foi entregue na sprint                              │
│  └── Revisão de critérios de aceite                                  │
│  └── Ajuste de prioridades para próxima semana                       │
│                                                                      │
│  Por fase (ao final de cada fase):                                   │
│  └── Review completo dos entregáveis da fase                         │
│  └── Validação contra critérios de aceite                            │
│  └── Lições aprendidas                                               │
│                                                                      │
│  Assíncrono:                                                         │
│  └── Swagger UI: contrato da API (Backend → Frontend)                │
│  └── Figma/ASCII: wireframes (Frontend → Time)                      │
│  └── Git commits: código (Todos → Orquestrador)                     │
│  └── README/Notion: documentação (Todos)                            │
└─────────────────────────────────────────────────────────────────────┘
```

### 11.4 Estimativa de Esforço Final

```
┌─────────────────────────────────────────────────────────────────────┐
│  CENÁRIO                          │ DURAÇÃO  │ EQUIPE               │
├───────────────────────────────────┼──────────┼──────────────────────┤
│  Time completo (2 back + 2 front   │ 12 sem.  │ 2 Backend (A3+A6)    │
│  + 1 DevOps + 1 PO)               │ (3 meses)│ 2 Frontend (A5)      │
│                                   │          │ 1 DevOps (A7)        │
│                                   │          │ 1 PO (A1)            │
│                                   │          │ (A2, A4, A8 = apoio) │
├───────────────────────────────────┼──────────┼──────────────────────┤
│  Time enxuto (1 back + 1 front    │ 18 sem.  │ 1 Fullstack Backend  │
│  + 1 DevOps/PO)                   │ (4.5 mes)│ 1 Frontend           │
│                                   │          │ 1 DevOps/PO          │
├───────────────────────────────────┼──────────┼──────────────────────┤
│  Desenvolvedor único              │ 26 sem.  │ 1 Fullstack          │
│                                   │ (6.5 mes)│                      │
└───────────────────────────────────┴──────────┴──────────────────────┘

Nota: Estimativas baseadas em 40h/semana por pessoa.
      Inclui desenvolvimento, testes, documentação e homologação.
```

---

**Documento gerado em 13/05/2026.**  
**Próximo passo:** Iniciar Sprint 0 — Setup e validação técnica.
