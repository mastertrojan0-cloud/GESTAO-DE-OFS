# ESPECIFICAÇÃO DE UX/UI — Sistema OFS/OFS MVP

**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Mapa de Telas](#1-mapa-de-telas)
2. [Fluxo do Observador](#2-fluxo-do-observador)
3. [Fluxo do Supervisor](#3-fluxo-do-supervisor)
4. [Fluxo do Gestor](#4-fluxo-do-gestor)
5. [Fluxo do Admin](#5-fluxo-do-admin)
6. [Wireframes Textuais](#6-wireframes-textuais)
7. [Regras de Navegação](#7-regras-de-navegação)
8. [Componentes Reutilizáveis](#8-componentes-reutilizáveis)
9. [Estados de Erro e Sucesso](#9-estados-de-erro-e-sucesso)
10. [Design System](#10-design-system)
11. [Regras de Responsividade](#11-regras-de-responsividade)
12. [Critérios de Aceite da Interface](#12-critérios-de-aceite-da-interface)

---

## 1. Mapa de Telas

```
┌─────────────────────────────────────────────────────────────┐
│                    SISTEMA OFS/OFS                           │
│                                                              │
│  ┌─────────┐                                                │
│  │  LOGIN  │────▶ (redireciona por perfil)                   │
│  └─────────┘                                                │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   INÍCIO (Dashboard)                  │   │
│  │  Cards: Hoje | Semana | Positivas | Negativas | Meta │   │
│  │  Botão principal: [+ NOVA OFS/OFS]                    │   │
│  └───────┬──────────────────────────────────────────────┘   │
│          │                                                    │
│  ┌───────┼──────────┬──────────────┬──────────────┐         │
│  ▼       ▼          ▼              ▼              ▼         │
│ ┌──────┐┌──────┐┌──────────┐┌──────────┐┌──────────────┐  │
│ │ NOVA ││CONSUL││ MÉTRICAS ││RELATÓRIOS││  CADASTROS   │  │
│ │ OFS  ││  TA  ││DA SEMANA ││          ││  (Admin)     │  │
│ └──┬───┘└──┬───┘└────┬─────┘└────┬─────┘└──────┬───────┘  │
│    │       │          │           │              │          │
│    ▼       ▼          ▼           ▼              ▼          │
│ ┌──────┐┌──────┐┌──────────┐┌──────────┐┌──────────────┐  │
│ │ VISUA││VISUA ││ EXPORTAR ││ DOWNLOAD ││  USUÁRIOS    │  │
│ │LIZAR ││LIZAR ││ PDF/EXCEL││   PDF    ││  EMPRESAS    │  │
│ │ OFS  ││ OFS  ││          ││          ││  CONTRATOS   │  │
│ │      ││      ││          ││          ││  LOCAIS      │  │
│ │ PDF  ││EDITAR││          ││          ││  METAS       │  │
│ │EDITAR││CANCEL││          ││          │└──────────────┘  │
│ │CANCEL││VOLTAR││          ││          │                   │
│ │VOLTAR││      ││          ││          │  ┌──────────────┐│
│ └──────┘└──────┘└──────────┘└──────────┘  │  AUDITORIA   ││
│                                            │  (Admin)     ││
│  ┌─────────────────────────────┐          └──────────────┘│
│  │         PERFIL              │                          │
│  │     (Alterar senha)         │                          │
│  └─────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

### Total: 15 Telas

| # | Tela | Rota | Observador | Supervisor | Gestor | Admin |
|---|------|------|:---:|:---:|:---:|:---:|
| 1 | Login | `/login` | ✅ | ✅ | ✅ | ✅ |
| 2 | Início | `/` | ✅ | ✅ | ✅ | ✅ |
| 3 | Nova OFS/OFS | `/OFS/novo` | ✅ | ✅ | ✅ | ✅ |
| 4 | OFS Salva (Sucesso) | `/OFS/:id/sucesso` | ✅ | ✅ | ✅ | ✅ |
| 5 | Consulta | `/consulta` | ✅ | ✅ | ✅ | ✅ |
| 6 | Visualizar OFS | `/OFS/:id` | ✅ | ✅ | ✅ | ✅ |
| 7 | Editar OFS | `/OFS/:id/editar` | 🔹⏱ | 🔸⏱ | ✅ | ✅ |
| 8 | Métricas | `/metricas` | ❌ | ✅ | ✅ | ✅ |
| 9 | Relatórios | `/relatorios` | ❌ | ❌ | ✅ | ✅ |
| 10 | Perfil | `/perfil` | ✅ | ✅ | ✅ | ✅ |
| 11 | Cadastro: Usuários | `/admin/usuarios` | ❌ | ❌ | ❌ | ✅ |
| 12 | Cadastro: Empresas | `/admin/empresas` | ❌ | ❌ | ❌ | ✅ |
| 13 | Cadastro: Contratos | `/admin/contratos` | ❌ | ❌ | ❌ | ✅ |
| 14 | Cadastro: Metas | `/admin/metas` | ❌ | ❌ | ✅ | ✅ |
| 15 | Auditoria | `/admin/auditoria` | ❌ | ❌ | ❌ | ✅ |

---

## 2. Fluxo do Observador

```
┌──────────────────────────────────────────────────────────────┐
│                    FLUXO DO OBSERVADOR                        │
│                                                               │
│  ┌─────────┐                                                  │
│  │  LOGIN  │  login: joao.silva, senha: ********              │
│  └────┬────┘                                                  │
│       │                                                       │
│       ▼                                                       │
│  ┌─────────────────────────────────────────────────┐         │
│  │              INÍCIO (Dashboard)                  │         │
│  │                                                  │         │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌───────┐  │         │
│  │  │ Hoje │ │Semana│ │Posit.│ │Negat.│ │ Meta  │  │         │
│  │  │  3   │ │  12  │ │  9   │ │  3   │ │  AT.  │  │         │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └───────┘  │         │
│  │                                                  │         │
│  │   ┌─────────────────────────┐                    │         │
│  │   │   ➕ NOVA OFS/OFS        │  ← AÇÃO PRINCIPAL │         │
│  │   └─────────────────────────┘                    │         │
│  │                                                  │         │
│  │   📋 Meus Registros  (lista dos últimos 10)      │         │
│  └────┬────────────────────────────────────────────┘         │
│       │                                                       │
│       ├──────────────────────┐                                │
│       ▼                      ▼                                │
│  ┌─────────────┐    ┌────────────────┐                       │
│  │ NOVA OFS/OFS│    │   CONSULTA     │                       │
│  │             │    │  (meus regist.)│                       │
│  │ preenche →  │    │  filtra →      │                       │
│  │ salva →     │    │  clica →       │                       │
│  │ mensagem OK │    │  visualiza     │                       │
│  │             │    │                │                       │
│  │ opções:     │    │  ações:        │                       │
│  │ • Ver OFS   │    │  • Visualizar  │                       │
│  │ • Novo OFS  │    │  • Gerar PDF   │                       │
│  │ • Voltar    │    │  • Editar (24h)│                       │
│  └─────────────┘    └────────────────┘                       │
│                                                               │
│  Observador NÃO vê:                                           │
│  ❌ Métricas da Semana                                        │
│  ❌ Relatórios                                                │
│  ❌ Cadastros (Admin)                                         │
│  ❌ Auditoria                                                 │
│  ❌ Registros de outros usuários                              │
└──────────────────────────────────────────────────────────────┘
```

### Sequência típica de uso (Observador):

```
1. Login → Início
2. Clica [+ NOVA OFS/OFS]
3. Preenche formulário (2-3 minutos)
4. Clica [SALVAR]
5. Vê mensagem de sucesso
6. Opcional: clica [GERAR PDF] para imprimir ou salvar
7. Volta ao Início ou cria novo registro
```

---

## 3. Fluxo do Supervisor

```
┌──────────────────────────────────────────────────────────────┐
│                    FLUXO DO SUPERVISOR                        │
│                                                               │
│  Mesmo fluxo básico do Observador, MAIS:                     │
│                                                               │
│  ➕ MÉTRICAS DA SEMANA                                        │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ ◀ Sem. Ant.  20/2026 (11/05 — 17/05)  Próx. Sem. ▶ │     │
│  │                                                      │     │
│  │ Contrato: [Operação SD ▾]                            │     │
│  │                                                      │     │
│  │ ┌────────┐┌────────┐┌────────────┐                  │     │
│  │ │ ADERÊNC││% SEGURO││  STATUS    │                  │     │
│  │ │  86%   ││ 80.6%  ││ 🟡 ATENÇÃO │                  │     │
│  │ └────────┘└────────┘└────────────┘                  │     │
│  │                                                      │     │
│  │ 8 cards de indicadores...                            │     │
│  │                                                      │     │
│  │ [Programado x Realizado] [Positivo x Negativo]       │     │
│  │ [OFS por Empresa      ] [OFS por Usuário  ]          │     │
│  │ [OFS por Turno        ] [Evolução Semanal ]          │     │
│  │                                                      │     │
│  │ [📄 EXPORTAR PDF] [📊 EXPORTAR EXCEL]               │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  ➕ RELATÓRIOS                                                │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  📄 Relatório Semanal    [GERAR PDF]                  │     │
│  │  📊 Relatório Mensal     [GERAR PDF]                  │     │
│  │  📈 Ranking Usuários     [GERAR PDF]                  │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  Supervisor vê registros de TODOS os usuários do contrato.    │
│  Pode editar registros do contrato em até 48h.               │
│  NÃO pode cancelar registros (apenas Gestor/Admin).          │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Fluxo do Gestor

```
┌──────────────────────────────────────────────────────────────┐
│                    FLUXO DO GESTOR                            │
│                                                               │
│  Mesmo fluxo do Supervisor, MAIS:                            │
│                                                               │
│  ➕ Vê TODAS as empresas e contratos (filtro multi-empresa)   │
│  ➕ Pode CANCELAR registros                                   │
│  ➕ Pode EDITAR sem limite de tempo                           │
│  ➕ Vê ranking entre empresas                                 │
│  ➕ Gerencia METAS semanais                                   │
│  ➕ Acesso a Cadastro de Metas                                │
│                                                               │
│  Painel Inicial do Gestor (já abre em Métricas):              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  RESUMO GERAL — Semana 20/2026                       │     │
│  │                                                      │     │
│  │  ┌──────────────┬──────────────┬──────────────┐      │     │
│  │  │ Sec. Dynamics│    G4S       │     ERA      │      │     │
│  │  │ Ad: 86% 🟡   │ Ad: 95% 🟡   │ Ad: 102% 🟢  │      │     │
│  │  │ Real: 645    │ Real: 380    │ Real: 510    │      │     │
│  │  │ Prog: 750    │ Prog: 400    │ Prog: 500    │      │     │
│  │  └──────────────┴──────────────┴──────────────┘      │     │
│  │                                                      │     │
│  │  [VER MÉTRICAS DETALHADAS]  [GERAR PDF SEMANAL]      │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. Fluxo do Admin

```
┌──────────────────────────────────────────────────────────────┐
│                    FLUXO DO ADMIN                             │
│                                                               │
│  Acesso TOTAL ao sistema. Setup inicial:                     │
│                                                               │
│  Primeiro Acesso:                                             │
│  1. Login → Altera senha padrão                              │
│  2. Cadastra Empresas (se necessário)                         │
│  3. Cadastra Contratos                                        │
│  4. Cadastra Locais                                           │
│  5. Cadastra Usuários (Observadores, Supervisores, Gestores)  │
│  6. Define Metas Semanais                                     │
│  7. Sistema pronto para uso operacional                       │
│                                                               │
│  Rotina:                                                      │
│  • Verifica Auditoria (quem fez o quê)                        │
│  • Gerencia usuários (ativar/desativar)                       │
│  • Ajusta metas                                               │
│  • Verifica backup                                            │
│  • Cancela/restaura registros quando necessário               │
│                                                               │
│  Telas exclusivas do Admin:                                   │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ CADASTROS                                            │    │
│  │  👥 Usuários    → CRUD + ativar/desativar            │    │
│  │  🏢 Empresas    → CRUD + ativar/desativar            │    │
│  │  📋 Contratos   → CRUD + ativar/desativar            │    │
│  │  📍 Locais      → CRUD (vinculados a contratos)      │    │
│  │  🎯 Metas       → Definir metas por contrato/semana  │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │ AUDITORIA                                            │    │
│  │  🔍 Logs de todas as ações do sistema               │    │
│  │  Filtros: usuário, ação, entidade, período           │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │ BACKUP (acessível na tela de Configurações)          │    │
│  │  💾 Status do último backup                          │    │
│  │  🔄 Backup manual                                    │    │
│  │  ⏪ Restaurar backup                                 │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## 6. Wireframes Textuais

### TELA 1 — LOGIN

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│                                                               │
│                    ┌─────────────────┐                        │
│                    │                 │                        │
│                    │  [LOGO SD]      │  ← 180px largura       │
│                    │                 │                        │
│                    └─────────────────┘                        │
│                                                               │
│              SISTEMA DE FEEDBACK COMPORTAMENTAL               │
│                       OFS / OFS                               │
│                                                               │
│         ┌─────────────────────────────────────┐              │
│         │  👤  Login ou E-mail                │              │
│         └─────────────────────────────────────┘              │
│                                                               │
│         ┌─────────────────────────────────────┐              │
│         │  🔒  Senha                          │              │
│         └─────────────────────────────────────┘              │
│                                                               │
│         ┌─────────────────────────────────────┐              │
│         │           ENTRAR                     │  ← vermelho  │
│         └─────────────────────────────────────┘              │
│                                                               │
│         ⚠ Usuário ou senha inválidos                         │
│         ⚠ Usuário bloqueado. Tente novamente em 30 min.      │
│         ⚠ Sessão expirada. Faça login novamente.             │
│                                                               │
│                                                               │
│              Security Dynamics © 2026                         │
│                                                               │
└──────────────────────────────────────────────────────────────┘

Cores:
  Fundo:        #F5F5F5 (cinza claro)
  Card login:   #FFFFFF (branco) com sombra sutil
  Input border: #D1D5DB
  Input focus:  #CC0000 (vermelho)
  Botão:        #CC0000 (fundo vermelho, texto branco)
  Botão hover:  #AA0000
  Erro:         #EF4444 (vermelho, texto 13px)
  Texto:        #1A1A1A (preto)
```

### TELA 2 — INÍCIO (DASHBOARD)

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ [LOGO SD]  SISTEMA OFS/OFS    👤 Admin  ⚙  ⏻ ││
│ │          │ └──────────────────────────────────────────────┘│
│ │ 📊 Início│                                                │
│ │ ➕ Nova  │  BEM-VINDO, CARLOS                               │
│ │    OFS   │  Perfil: Supervisor | Contrato: Operação SD     │
│ │ 🔍 Cons. │                                                │
│ │ 📈 Mét.  │  ┌──────────┐┌──────────┐┌──────────┐┌───────┐ │
│ │ 📄 Rel.  │  │ 🟢 Hoje  ││📋 Semana ││✅ Positiv││❌ Negat│ │
│ │ ─────── │  │          ││          ││          ││        │ │
│ │ 👥 Usuár.│  │    3     ││    12    ││    9     ││   3    │ │
│ │ 🏢 Empr. │  │ registros││ registros││ positivas││negativas│ │
│ │ 📋 Contr.│  └──────────┘└──────────┘└──────────┘└───────┘ │
│ │ 🎯 Metas │  ┌────────────────────────────────────────┐     │
│ │ 🔍 Audit │  │         STATUS DA META SEMANAL         │     │
│ │ ⚙ Config │  │  Aderência: 86% — 🟡 ATENÇÃO          │     │
│ │          │  │  Realizadas: 645 de 750 programadas    │     │
│ │          │  │  Faltam 105 registros até a meta       │     │
│ │          │  └────────────────────────────────────────┘     │
│ │          │                                                │
│ │          │  ┌──────────────────────────────────────┐      │
│ │          │  │          ➕ NOVA OFS/OFS              │      │
│ │          │  │    Clique para registrar uma          │      │
│ │          │  │    observação comportamental          │      │
│ │          │  └──────────────────────────────────────┘      │
│ │          │                                                │
│ │          │  ÚLTIMOS REGISTROS                              │
│ │          │  ┌──────┬──────────┬──────────┬────────┬──────┐│
│ │          │  │Código│ Data     │Observado │Tipo    │Status││
│ │          │  ├──────┼──────────┼──────────┼────────┼──────┤│
│ │          │  │ 1523 │13/05 14:3│João Silva│Positivo│Gerado││
│ │          │  │ 1522 │13/05 09:1│Maria Souz│Negativo│Gerado││
│ │          │  │ 1521 │12/05 16:0│Pedro Lima│Positivo│Editad││
│ │          │  └──────┴──────────┴──────────┴────────┴──────┘│
│ │          │  [VER TODOS →]                                  │
│ └──────────┘                                                │
└──────────────────────────────────────────────────────────────┘
```

### TELA 3 — NOVA OFS/OFS

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ ← VOLTAR      NOVA OFS/OFS                   ││
│ └──────────┘ └──────────────────────────────────────────────┘│
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ DADOS AUTOMÁTICOS (não editáveis)                       │ │
│  │                                                          │ │
│  │ Código: AUTO (gerado ao salvar)                          │ │
│  │ Data:   13/05/2026    Hora: 14:30                       │ │
│  │                                                          │ │
│  │ Usuário: Carlos Henrique Oliveira                        │ │
│  │ E-mail:  carlos.oliveira@securitydynamics.com.br         │ │
│  │ Perfil:  Supervisor                                      │ │
│  │ Empresa: Security Dynamics                               │ │
│  │ Contrato: Operação Security Dynamics                     │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ DADOS DA OBSERVAÇÃO                                     │ │
│  │                                                          │ │
│  │ Empresa Observada *                                      │ │
│  │ ┌──────────────────────────────────────┐                 │ │
│  │ │ Security Dynamics              ▾     │                 │ │
│  │ └──────────────────────────────────────┘                 │ │
│  │                                                          │ │
│  │ ⚠ Se selecionar "Outros":                               │ │
│  │ Nome da Empresa Observada *                              │ │
│  │ ┌──────────────────────────────────────┐                 │ │
│  │ │                                      │                 │ │
│  │ └──────────────────────────────────────┘                 │ │
│  │                                                          │ │
│  │ Nome do Observado *                    Local Observado * │ │
│  │ ┌──────────────────────┐ ┌────────────────────────────┐  │ │
│  │ │ João Silva Santos    │ │ Armazém B                  │  │ │
│  │ └──────────────────────┘ └────────────────────────────┘  │ │
│  │                                                          │ │
│  │ Atividade Observada *                                    │ │
│  │ ┌──────────────────────────────────────┐                 │ │
│  │ │ Operação de empilhadeira             │                 │ │
│  │ └──────────────────────────────────────┘                 │ │
│  │                                                          │ │
│  │ Turno *                         Tipo da Observação *     │ │
│  │ ┌──────────────────────┐ ┌────────────────────────────┐  │ │
│  │ │ Diurno          ▾    │ │ ○ Positivo / Seguro        │  │ │
│  │ └──────────────────────┘ │ ● Negativo / Inseguro      │  │ │
│  │                          └────────────────────────────┘  │ │
│  │                                                          │ │
│  │ Comportamento Observado *                                │ │
│  │ ┌──────────────────────────────────────┐                 │ │
│  │ │                                      │                 │ │
│  │ │                                      │                 │ │
│  │ └──────────────────────────────────────┘                 │ │
│  │                                                          │ │
│  │ Observação Complementar                                  │ │
│  │ ┌──────────────────────────────────────┐                 │ │
│  │ │                                      │                 │ │
│  │ └──────────────────────────────────────┘                 │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ 💾 SALVAR  │  │ 📄 SALVAR E    │  │ 🗑 LIMPAR  ✕ CANC. │  │
│  │  REGISTRO  │  │   GERAR PDF    │  │                     │  │
│  └────────────┘  └────────────────┘  └────────────────────┘  │
│                                                               │
│  * Campos obrigatórios                                       │
└──────────────────────────────────────────────────────────────┘
```

### TELA 4 — OFS SALVA (SUCESSO)

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│                      ✅ SUCESSO!                              │
│                                                               │
│            Registro OFS/OFS gerado com sucesso                │
│                                                               │
│                   ┌──────────────┐                            │
│                   │  Nº OFS/OFS  │                            │
│                   │              │                            │
│                   │    1523      │  ← número grande           │
│                   │              │                            │
│                   └──────────────┘                            │
│                                                               │
│            Data: 13/05/2026   Hora: 14:30                     │
│            Tipo: Positivo / Seguro                            │
│            Observado: João Silva Santos                       │
│            Empresa: Security Dynamics                         │
│                                                               │
│     ┌──────────────────┐  ┌──────────────────┐               │
│     │  👁 VER REGISTRO │  │  📄 GERAR PDF    │               │
│     └──────────────────┘  └──────────────────┘               │
│                                                               │
│     ┌──────────────────┐  ┌──────────────────┐               │
│     │ ➕ NOVA OFS/OFS  │  │  🏠 INÍCIO       │               │
│     └──────────────────┘  └──────────────────┘               │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### TELA 5 — CONSULTA DE REGISTROS

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ CONSULTA DE REGISTROS                        ││
│ └──────────┘ └──────────────────────────────────────────────┘│
│                                                               │
│  FILTROS                                                      │
│  ┌──────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │Código│ │Data Iníc.│ │Data Fim  │ │ Semana   │ │  Mês   │ │
│  │      │ │          │ │          │ │          │ │        │ │
│  └──────┘ └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│  ┌──────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │ Ano  │ │Usuário ▾ │ │Empresa ▾ │ │Local     │ │Turno ▾ │ │
│  └──────┘ └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                     │
│  │ Tipo   ▾ │ │Contrato▾ │ │Status  ▾ │                     │
│  └──────────┘ └──────────┘ └──────────┘                     │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │🔍 BUSCAR │  │🗑 LIMPAR │  │📥 EXPORTAR│ ← Resultado: 47  │
│  └──────────┘  └──────────┘  └──────────┘                   │
│                                                               │
│  RESULTADOS                                                   │
│  ┌──────┬──────────┬──────────┬──────────┬──────┬──────┬────┐│
│  │Código│ Data     │Observado │Empresa   │Tipo  │Status│Ação││
│  ├──────┼──────────┼──────────┼──────────┼──────┼──────┼────┤│
│  │ 1523 │13/05/2026│João Silva│Sec. Dyn. │Posit.│Gerado│👁📄 ││
│  │ 1522 │13/05/2026│Maria S.  │G4S       │Negat.│Gerado│👁📄 ││
│  │ 1521 │12/05/2026│Pedro Lima│ERA       │Posit.│Edita.│👁📄✎││
│  │ 1520 │12/05/2026│Ana Costa │Polo Norte│Negat.│Cancel│👁  ││
│  │ ...  │...       │...       │...       │...   │...   │... ││
│  └──────┴──────────┴──────────┴──────────┴──────┴──────┴────┘│
│                                                               │
│  ◀ Página 1 de 2 ▶                  25 itens por página ▾    │
└──────────────────────────────────────────────────────────────┘
```

### TELA 6 — VISUALIZAR OFS

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ ← VOLTAR    VISUALIZAR REGISTRO OFS/OFS      ││
│ └──────────┘ └──────────────────────────────────────────────┘│
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Nº OFS/OFS: 1523                    Status: GERADO  │    │
│  │                                      ┌──────────────┐│    │
│  │                                      │   🟢 GERADO  ││    │
│  │                                      └──────────────┘│    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────┐  ┌────────────────────────────────┐ │
│  │ DADOS GERAIS        │  │ DADOS DA OBSERVAÇÃO            │ │
│  ├─────────────────────┤  ├────────────────────────────────┤ │
│  │ Data: 13/05/2026    │  │ Empresa: Security Dynamics     │ │
│  │ Hora: 14:30         │  │ Observado: João Silva Santos   │ │
│  │ Semana: 20 / 2026   │  │ Atividade: Oper. empilhadeira  │ │
│  │                     │  │ Local: Armazém B               │ │
│  │ Gerado por:         │  │ Turno: Diurno                  │ │
│  │ Carlos H. Oliveira  │  │ Contrato: Operação SD          │ │
│  │ Supervisor          │  │                                │ │
│  │ Security Dynamics   │  │ Tipo: ✅ Positivo / Seguro     │ │
│  └─────────────────────┘  └────────────────────────────────┘ │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ COMPORTAMENTO OBSERVADO                               │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │ Uso correto de todos os EPIs obrigatórios: capacete,  │    │
│  │ luva, bota e colete. Verificou área antes de iniciar  │    │
│  │ operação.                                             │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ OBSERVAÇÃO COMPLEMENTAR                               │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │ Operador demonstrou atenção redobrada aos procedimentos│    │
│  │ de segurança.                                         │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ HISTÓRICO DE ALTERAÇÕES                               │    │
│  ├──────────┬──────────┬──────────┬──────────┬──────────┤    │
│  │ Data     │ Usuário  │ Campo    │ De       │ Para     │    │
│  ├──────────┼──────────┼──────────┼──────────┼──────────┤    │
│  │13/05 16:4│Carlos O. │Comportam.│Uso corre.│Uso corre.│    │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘    │
│  (vazio se nunca editado)                                     │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │📄 GERAR  │ │🖨 IMPRIMIR│ │✎ EDITAR  │ │⛔ CANCEL.│        │
│  │   PDF    │ │          │ │(se permit)│ │(se permit)│        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
└──────────────────────────────────────────────────────────────┘
```

### TELA 7 — MÉTRICAS DA SEMANA (PAINEL PRINCIPAL DO MVP)

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ MÉTRICAS DA SEMANA                           ││
│ └──────────┘ └──────────────────────────────────────────────┘│
│                                                               │
│  ◀ Semana Anterior          Semana 20/2026         Próx. Sem.▶│
│                       11/05/2026 — 17/05/2026                 │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │Contrato▾ │ │Empresa ▾ │ │ Turno  ▾ │ │Usuário ▾ │        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
│                                                               │
│  ═══════════ INDICADORES PRINCIPAIS ═══════════               │
│                                                               │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │  ADERÊNCIA   │ │  % SEGURO    │ │   STATUS             │  │
│  │              │ │              │ │                      │  │
│  │    86.0%     │ │   80.6%      │ │   🟡 ATENÇÃO         │  │
│  │              │ │              │ │                      │  │
│  │  Meta: 100%  │ │  Meta: >90%  │ │ Aderência entre      │  │
│  │              │ │              │ │ 80% e 99%            │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
│                                                               │
│  ═══════════ INDICADORES DETALHADOS ═══════════               │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │ Pessoas  │ │ OFS      │ │ OFS      │ │ Positivas│        │
│  │ Ativas   │ │Programada│ │Realizada │ │          │        │
│  │   150    │ │   750    │ │   645    │ │   520    │        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
│                                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │Negativas │ │ Usuários │ │ Média por│ │ % Desvio │        │
│  │          │ │ Ativos   │ │ Usuário  │ │          │        │
│  │   125    │ │    9     │ │   71.7   │ │  19.4%   │        │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
│                                                               │
│  ═══════════ GRÁFICOS ═══════════                             │
│                                                               │
│  ┌─────────────────────────┐ ┌─────────────────────────┐     │
│  │ Programado x Realizado  │ │ Positivo x Negativo     │     │
│  │                         │ │                         │     │
│  │   ▓▓▓▓▓▓▓▓▓▓ 750       │ │     ┌─────────┐        │     │
│  │   ▓▓▓▓▓▓▓▓▓  645       │ │     │ 80.6%   │ Verde  │     │
│  │   Program. Realiz.     │ │     │ Positivo│        │     │
│  │                         │ │     │ 19.4%   │ Vermelh│     │
│  │                         │ │     └─────────┘        │     │
│  └─────────────────────────┘ └─────────────────────────┘     │
│                                                               │
│  ┌─────────────────────────┐ ┌─────────────────────────┐     │
│  │ OFS por Empresa         │ │ OFS por Usuário         │     │
│  │ SD     ▓▓▓▓▓▓▓▓▓ 645   │ │ Carlos  ▓▓▓▓▓ 85       │     │
│  │ G4S    ▓▓▓▓▓ 380       │ │ Ana     ▓▓▓▓ 72        │     │
│  │ ERA    ▓▓▓▓▓▓ 510      │ │ Pedro   ▓▓▓ 58         │     │
│  └─────────────────────────┘ └─────────────────────────┘     │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ Evolução Semanal (últimas 8 semanas)                  │   │
│  │                                                       │   │
│  │ 120%┤          ●──●                                   │   │
│  │ 100%┤  ●──●──●     ●──●──●    ─ ─ Meta 100%          │   │
│  │  80%┤                   ●──●   ─ ─ Alerta 80%        │   │
│  │  60%┤                                                │   │
│  │      ├───┼───┼───┼───┼───┼───┼───┼───               │   │
│  │      S13 S14 S15 S16 S17 S18 S19 S20                  │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ═══════════ TABELA CONSOLIDADA ═══════════                   │
│                                                               │
│  ┌──────────┬──────┬──────┬──────┬──────┬──────┬──────┬────┐ │
│  │ Contrato │Pes.At│Prog. │Real. │Posit.│Negat.│Ader.%│Sta │ │
│  ├──────────┼──────┼──────┼──────┼──────┼──────┼──────┼────┤ │
│  │OperaçãoSD│ 150  │ 750  │ 645  │ 520  │ 125  │ 86%  │🟡  │ │
│  │G4S       │  80  │ 400  │ 380  │ 310  │  70  │ 95%  │🟡  │ │
│  │ERA       │ 100  │ 500  │ 510  │ 450  │  60  │102%  │🟢  │ │
│  └──────────┴──────┴──────┴──────┴──────┴──────┴──────┴────┘ │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │📄 EXPORTAR│  │📊 EXPORTAR│  │🖨 IMPRIMIR│                   │
│  │   PDF     │  │   EXCEL   │  │          │                   │
│  └──────────┘  └──────────┘  └──────────┘                   │
└──────────────────────────────────────────────────────────────┘
```

### TELA 8 — RELATÓRIOS

```
┌──────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ RELATÓRIOS                                   ││
│ └──────────┘ └──────────────────────────────────────────────┘│
│                                                               │
│  ═══════════ GERAR RELATÓRIO ═══════════                      │
│                                                               │
│  ┌─────────────────────────┐ ┌────────────────────────────┐  │
│  │ 📄 RELATÓRIO INDIVIDUAL │ │ 📊 RELATÓRIO SEMANAL       │  │
│  │                         │ │                            │  │
│  │ Registro único de OFS   │ │ Métricas completas com     │  │
│  │ com cabeçalho e rodapé  │ │ indicadores e gráficos     │  │
│  │ corporativo             │ │                            │  │
│  │                         │ │ Semana: [20/2026 ▾]        │  │
│  │ Nº OFS: [__________]    │ │ Contrato: [Operação SD ▾]  │  │
│  │                         │ │                            │  │
│  │ [ GERAR PDF ]           │ │ [ GERAR PDF ]              │  │
│  └─────────────────────────┘ └────────────────────────────┘  │
│                                                               │
│  ┌─────────────────────────┐ ┌────────────────────────────┐  │
│  │ 📈 RELATÓRIO MENSAL     │ │ 🏆 RANKING POR EMPRESA     │  │
│  │                         │ │                            │  │
│  │ Consolidado do mês com  │ │ Empresas ordenadas por     │  │
│  │ evolução semanal        │ │ aderência %                │  │
│  │                         │ │                            │  │
│  │ Mês: [05/2026 ▾]        │ │ Semana: [20/2026 ▾]        │  │
│  │ Contrato: [Operação ▾]  │ │                            │  │
│  │                         │ │                            │  │
│  │ [ GERAR PDF ]           │ │ [ GERAR PDF ]              │  │
│  └─────────────────────────┘ └────────────────────────────┘  │
│                                                               │
│  ┌─────────────────────────┐ ┌────────────────────────────┐  │
│  │ 👤 RANKING POR USUÁRIO  │ │ 📉 HISTÓRICO DE DESVIOS    │  │
│  │                         │ │                            │  │
│  │ Usuários com mais       │ │ Comportamentos inseguros   │  │
│  │ registros gerados       │ │ mais frequentes            │  │
│  │                         │ │                            │  │
│  │ Semana: [20/2026 ▾]     │ │ Período: [Último mês ▾]   │  │
│  │ Contrato: [Operação ▾]  │ │                            │  │
│  │                         │ │                            │  │
│  │ [ GERAR PDF ]           │ │ [ GERAR PDF ]              │  │
│  └─────────────────────────┘ └────────────────────────────┘  │
│                                                               │
│  ═══════════ HISTÓRICO DE RELATÓRIOS ═══════════              │
│                                                               │
│  ┌──────────────────────────────┬──────────┬────────┬──────┐ │
│  │ Relatório                    │ Gerado em│ Por    │ Baix.│ │
│  ├──────────────────────────────┼──────────┼────────┼──────┤ │
│  │ OFC_1523_JoaoSilva_13052026  │13/05 14:3│Carlos  │ ⬇   │ │
│  │ METRICAS_SEMANAL_S20_2026    │13/05 14:3│Carlos  │ ⬇   │ │
│  │ METRICAS_SEMANAL_S19_2026    │06/05 10:1│Admin   │ ⬇   │ │
│  └──────────────────────────────┴──────────┴────────┴──────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. Regras de Navegação

### 7.1 Estrutura do Layout Base

```
┌──────────────────────────────────────────────────────────┐
│                        HEADER                             │
│  [☰] [LOGO]  TÍTULO DO SISTEMA     [👤 USUÁRIO] [⚙][⏻] │
├──────────┬───────────────────────────────────────────────┤
│          │                                                │
│  SIDEBAR │          ÁREA DE CONTEÚDO                     │
│          │          (renderiza a rota atual)              │
│  • Link1 │                                                │
│  • Link2 │                                                │
│  • Link3 │                                                │
│          │                                                │
│          │                                                │
├──────────┴───────────────────────────────────────────────┤
│                     (sem footer fixo)                     │
└──────────────────────────────────────────────────────────┘
```

### 7.2 Header

| Elemento | Posição | Ação |
|----------|---------|------|
| ☰ (hamburger) | Esquerda | Abre/fecha sidebar (mobile) |
| Logo SD | Esquerda (após hamburger) | Link para Início |
| Título "SISTEMA OFS/OFS" | Esquerda (após logo) | Nenhuma |
| 👤 Nome do Usuário | Direita | Dropdown: Perfil, Sair |
| ⚙ Configurações | Direita | Link para Perfil |
| ⏻ Sair | Direita | Logout |

### 7.3 Sidebar

| Seção | Links | Visível para |
|-------|-------|:---:|
| **Principal** | | |
| | 📊 Início | Todos |
| | ➕ Nova OFS/OFS | Todos |
| | 🔍 Consulta | Todos |
| **Análise** | | |
| | 📈 Métricas da Semana | Supervisor, Gestor, Admin |
| | 📄 Relatórios | Gestor, Admin |
| **Administração** | | |
| | 👥 Usuários | Admin |
| | 🏢 Empresas | Admin |
| | 📋 Contratos | Admin |
| | 📍 Locais | Admin |
| | 🎯 Metas | Gestor, Admin |
| | 🔍 Auditoria | Admin |

### 7.4 Breadcrumb

```
Início > Consulta > Visualizar OFS #1523
```

- Exibido abaixo do Header
- Cada segmento é clicável (exceto o último)
- Separação com `>` ou `/`

### 7.5 Redirecionamento por Perfil (após login)

| Perfil | Tela Inicial |
|--------|-------------|
| Observador | Início (Dashboard focado em "Nova OFS") |
| Supervisor | Início (Dashboard com métricas do contrato) |
| Gestor | Métricas da Semana (visão geral) |
| Admin | Início (Dashboard com resumo do sistema) |

### 7.6 Atalhos de Teclado (MVP)

| Atalho | Ação |
|--------|------|
| `Ctrl + N` | Nova OFS/OFS |
| `Ctrl + F` | Consulta |
| `Ctrl + M` | Métricas |
| `Esc` | Fechar modal / Cancelar |
| `Enter` | Submeter formulário |

---

## 8. Componentes Reutilizáveis

### 8.1 Hierarquia de Componentes

```
App
├── AuthProvider (contexto de autenticação)
│   ├── LoginPage
│   └── AppShell (layout logado)
│       ├── Header
│       │   ├── Logo
│       │   ├── UserMenu (dropdown)
│       │   └── HamburgerButton (mobile)
│       ├── Sidebar
│       │   ├── SidebarSection (agrupador)
│       │   └── SidebarLink (item de menu)
│       ├── Breadcrumb
│       └── MainContent (<Outlet/>)
│           └── (páginas)
│               ├── Card (container)
│               ├── StatCard (indicador numérico)
│               ├── StatusBadge (OK/ATENÇÃO/ALERTA)
│               ├── Table<T> (tabela genérica)
│               │   ├── TableHeader (com sort)
│               │   ├── TableRow
│               │   └── Pagination
│               ├── FilterBar (barra de filtros)
│               ├── FormField (input/select/date com label e erro)
│               ├── Modal (confirmação, formulário)
│               ├── Toast (notificação)
│               ├── Spinner (loading)
│               ├── EmptyState (sem dados)
│               ├── ErrorState (erro)
│               ├── ConfirmDialog (sim/não)
│               ├── BarChartCard (gráfico de barras)
│               ├── PieChartCard (gráfico de pizza)
│               └── LineChartCard (gráfico de linha)
```

### 8.2 Catálogo de Componentes

#### 🧱 UI Base

| Componente | Props | Estados |
|-----------|-------|---------|
| `Button` | variant (primary|secondary|danger|ghost), size (sm|md|lg), loading, disabled, icon, onClick | default, hover, active, focus, disabled, loading |
| `Input` | label, type, placeholder, value, onChange, error, required, disabled | default, focus, error, disabled |
| `Select` | label, options[{value, label}], value, onChange, error, required, disabled | default, open, error, disabled |
| `DatePicker` | label, value, onChange, min, max, error | default, focus, error |
| `Textarea` | label, rows, value, onChange, error, required | default, focus, error |
| `Checkbox` | label, checked, onChange | default, checked, disabled |
| `RadioGroup` | label, options[{value, label}], value, onChange | default |
| `Toggle` | label, checked, onChange | off, on |

#### 📦 Containers

| Componente | Props | Descrição |
|-----------|-------|-----------|
| `Card` | title, subtitle, children, action, padding, className | Container com sombra e borda |
| `StatCard` | label, value, icon, trend (up|down|neutral), color | Card de indicador numérico |
| `Modal` | open, onClose, title, size (sm|md|lg), children | Overlay com conteúdo centralizado |
| `ConfirmDialog` | open, title, message, onConfirm, onCancel, confirmText, variant | Diálogo de confirmação |
| `PageHeader` | title, subtitle, actions, onBack | Cabeçalho de página com breadcrumb |

#### 📊 Dados

| Componente | Props | Descrição |
|-----------|-------|-----------|
| `Table<T>` | columns[{key, label, sortable, render}], data, loading, error, emptyMessage, onRowClick, sortKey, sortDir, onSort | Tabela genérica tipada |
| `Pagination` | page, totalPages, onPageChange, pageSize, onPageSizeChange | Navegação de páginas |
| `FilterBar` | filters[{key, label, type, options}], values, onChange, onSearch, onClear | Barra de filtros |
| `StatusBadge` | status, type (OFS|meta) | Badge colorido: Gerado/Editado/Cancelado ou OK/ATENÇÃO/ALERTA |

#### 📈 Gráficos

| Componente | Props | Descrição |
|-----------|-------|-----------|
| `BarChartCard` | title, data, xKey, yKey, color, height | Gráfico de barras wrapper |
| `PieChartCard` | title, data, nameKey, valueKey, colors, donut | Gráfico de pizza/rosca |
| `LineChartCard` | title, data, xKey, lines[{key, color, name}], references[{y, label, color}] | Gráfico de linha |

#### 💬 Feedback

| Componente | Props | Descrição |
|-----------|-------|-----------|
| `Toast` | (gerenciado por sonner) | Notificação toast |
| `Spinner` | size (sm|md|lg) | Indicador de carregamento |
| `EmptyState` | icon, title, description, action | Estado vazio com ação |
| `ErrorState` | title, message, onRetry | Estado de erro com botão retry |
| `SuccessMessage` | title, message, actions[{label, onClick}] | Mensagem de sucesso pós-ação |

#### 🔐 Auth

| Componente | Props | Descrição |
|-----------|-------|-----------|
| `ProtectedRoute` | allowedRoles, children | Guard de rota por perfil |
| `PermissionGate` | action, children | Mostra/esconde por permissão |

---

## 9. Estados de Erro e Sucesso

### 9.1 Tela de Login

| Estado | Mensagem | Visual |
|--------|----------|--------|
| Campo vazio | "Login é obrigatório" | Texto vermelho abaixo do input |
| Credenciais inválidas | "Usuário ou senha inválidos" | Banner vermelho abaixo do botão Entrar |
| Usuário inativo | "Usuário desativado. Contate o administrador." | Banner vermelho |
| Bloqueio por tentativas | "Usuário bloqueado por 30 minutos. Tente novamente às 15:30." | Banner amarelo com ícone 🔒 |
| Sessão expirada | "Sessão expirada. Faça login novamente." | Redireciona para /login com mensagem |
| Sucesso | — | Redireciona para tela inicial |

### 9.2 Formulário Nova OFS/OFS

| Estado | Mensagem | Visual |
|--------|----------|--------|
| Campo obrigatório vazio | "Nome do observado é obrigatório" | Texto vermelho abaixo do campo |
| Empresa "Outros" sem nome | "Informe o nome da empresa observada" | Campo extra aparece com borda vermelha |
| Comportamento < 5 caracteres | "Mínimo de 5 caracteres" | Texto vermelho |
| Erro de rede | "Erro ao salvar. Verifique sua conexão." | Toast vermelho |
| Erro 403 | "Você não tem permissão para esta ação." | Toast vermelho |
| Erro 409 (conflito) | "Este registro foi modificado por outro usuário." | Toast amarelo |
| Erro 500 | "Erro interno do servidor. Tente novamente." | Toast vermelho |
| Salvando... | — | Botão com spinner, desabilitado |
| Salvo com sucesso! | "Registro OFS/OFS #1523 gerado com sucesso" | Tela de sucesso (Tela 4) |

### 9.3 Tabelas (Consulta, Usuários, etc.)

| Estado | Mensagem | Visual |
|--------|----------|--------|
| Carregando | — | Spinner centralizado na área da tabela |
| Vazio (sem filtros) | "Nenhum registro encontrado. Clique em [+ Nova OFS] para começar." | Ícone + texto + botão ação |
| Vazio (com filtros) | "Nenhum resultado para os filtros aplicados." | Ícone + texto + botão "Limpar filtros" |
| Erro de rede | "Não foi possível carregar os dados." | Ícone + texto + botão "Tentar novamente" |
| Paginação sem dados | "Página X de Y — Nenhum registro nesta página" | Texto informativo |

### 9.4 Métricas

| Estado | Mensagem | Visual |
|--------|----------|--------|
| Sem meta cadastrada | "Nenhuma meta encontrada para esta semana. Cadastre uma meta em Admin > Metas." | Banner amarelo com link |
| Semana sem registros | "Nenhum OFS registrado nesta semana." | Cards com valor 0, status "ALERTA" |
| Carregando | — | Skeleton nos cards e gráficos |
| Erro | "Erro ao carregar métricas." | Botão "Tentar novamente" |

### 9.5 PDF

| Estado | Mensagem | Visual |
|--------|----------|--------|
| Gerando PDF... | "Gerando PDF. Isso pode levar alguns segundos..." | Spinner + texto no card do relatório |
| PDF pronto | "PDF gerado com sucesso!" | Link de download aparece + toast |
| Erro na geração | "Erro ao gerar PDF. Tente novamente." | Toast vermelho |

### 9.6 Cancelamento de OFS (Modal)

| Estado | Mensagem | Visual |
|--------|----------|--------|
| Modal aberto | "Tem certeza que deseja cancelar o registro #1523?" | Modal com textarea para motivo + botões Confirmar/Cancelar |
| Motivo vazio | "Informe o motivo do cancelamento" | Texto vermelho abaixo do textarea |
| Confirmado | "Registro #1523 cancelado com sucesso" | Toast verde, registro some da lista (ou fica como Cancelado) |

---

## 10. Design System

### 10.1 Paleta de Cores

```
┌─────────────────────────────────────────────────────────────┐
│                     PALETA DE CORES                          │
│                                                              │
│  PRIMÁRIA                                                    │
│  ┌────────┬────────┬────────┬────────┬────────┐             │
│  │ #990000│ #CC0000│ #DC2626│ #EF4444│ #FEE2E2│             │
│  │  900   │  700   │  600   │  500   │  100   │             │
│  └────────┴────────┴────────┴────────┴────────┘             │
│  hover    primary   active   danger   bg-light               │
│                                                              │
│  NEUTRAS                                                     │
│  ┌────────┬────────┬────────┬────────┬────────┐             │
│  │ #1A1A1A│ #4B5563│ #9CA3AF│ #E5E7EB│ #F5F5F5│             │
│  │ texto  │ texto  │ border │ border │ bg     │             │
│  │ preto  │ cinza  │ cinza  │ cinza  │ cinza  │             │
│  └────────┴────────┴────────┴────────┴────────┘             │
│                                                              │
│  SEMÂNTICAS                                                  │
│  ┌────────┬────────┬────────┬────────┐                      │
│  │ #16A34A│ #22C55E│ #EAB308│ #F59E0B│                      │
│  │ sucesso│ sucesso│ alerta │ alerta │                      │
│  │ hover  │        │ hover  │        │                      │
│  └────────┴────────┴────────┴────────┘                      │
│                                                              │
│  FUNDOS                                                      │
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │ #FFFFFF (surface)     │  │ #F5F5F5 (background) │         │
│  │ cards, inputs, modals │  │ corpo da página       │         │
│  └──────────────────────┘  └──────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### 10.2 Tipografia

```
Fonte: Inter (arquivos .woff2 locais)

┌──────────────────────────────────────────────────────┐
│  Display  —  Inter Bold      24px / 32px             │
│  Heading  —  Inter SemiBold  20px / 28px             │
│  Title    —  Inter SemiBold  18px / 24px             │
│  Subtitle —  Inter SemiBold  16px / 22px             │
│  Body     —  Inter Regular   14px / 20px             │
│  Small    —  Inter Regular   12px / 16px             │
│  Caption  —  Inter Regular   11px / 14px             │
└──────────────────────────────────────────────────────┘

Pesos disponíveis: 400 (Regular), 600 (SemiBold), 700 (Bold)
```

### 10.3 Espaçamento (Grid 8px)

```
┌──────────────────────────────────────────────┐
│  xs  — 4px   (0.5 unidade)                   │
│  sm  — 8px   (1 unidade)                     │
│  md  — 16px  (2 unidades)                    │
│  lg  — 24px  (3 unidades)                    │
│  xl  — 32px  (4 unidades)                    │
│  2xl — 48px  (6 unidades)                    │
│  3xl — 64px  (8 unidades)                    │
└──────────────────────────────────────────────┘
```

### 10.4 Bordas e Sombras

```css
/* Bordas */
border-radius: 6px;   /* inputs, buttons */
border-radius: 8px;   /* cards */
border-radius: 12px;  /* modais */
border-radius: 9999px; /* badges, pills */

border-color: #E5E7EB; /* padrão */
border-color: #CC0000; /* foco (primária) */
border-color: #EF4444; /* erro */

/* Sombras */
shadow-sm:  0 1px 2px rgba(0,0,0,0.05);   /* cards */
shadow-md:  0 4px 6px rgba(0,0,0,0.07);   /* modais, dropdowns */
shadow-lg:  0 10px 15px rgba(0,0,0,0.1);  /* modais grandes */

/* Foco */
ring: 0 0 0 3px rgba(204,0,0,0.2);  /* anel vermelho no foco */
```

### 10.5 Ícones (Lucide React)

```
Usar ícones do Lucide React (SVG inline, tree-shaking):

🔍 Search         — <Search />
➕ Plus           — <Plus />          (Nova OFS)
📋 ClipboardList  — <ClipboardList /> (Consulta)
📊 BarChart3      — <BarChart3 />     (Métricas)
📄 FileText       — <FileText />      (Relatórios)
👤 User           — <User />          (Usuários)
🏢 Building2      — <Building2 />     (Empresas)
📋 FileText       — <FileCheck />     (Contratos)
📍 MapPin         — <MapPin />        (Locais)
🎯 Target         — <Target />        (Metas)
🔍 ShieldCheck    — <ShieldCheck />   (Auditoria)
📥 Download       — <Download />      (Exportar/Download)
🖨 Printer        — <Printer />       (Imprimir)
✎ Edit           — <Pencil />        (Editar)
⛔ Ban            — <Ban />           (Cancelar)
👁 Eye            — <Eye />           (Visualizar)
🗑 Trash2         — <Trash2 />        (Limpar filtros)
⬇ ChevronDown    — <ChevronDown />   (Dropdown)
✕ X              — <X />             (Fechar)
← ArrowLeft      — <ArrowLeft />     (Voltar)
→ ArrowRight     — <ArrowRight />    (Avançar)
⚠ AlertTriangle  — <AlertTriangle /> (Alerta)
✅ CheckCircle   — <CheckCircle />   (Sucesso)
❌ XCircle        — <XCircle />       (Erro)
⏻ LogOut         — <LogOut />        (Sair)
⚙ Settings       — <Settings />      (Configurações)
⏳ Loader2        — <Loader2 />       (Spinner animado)
📦 PackageOpen   — <PackageOpen />   (EmptyState)
```

### 10.6 Tokens CSS (Tailwind Config)

```typescript
// tailwind.config.ts
export default {
  theme: {
    extend: {
      colors: {
        brand: {
          red:    { 100: '#FEE2E2', 500: '#EF4444', 600: '#DC2626', 700: '#CC0000', 900: '#990000' },
          black:  { DEFAULT: '#1A1A1A', muted: '#4B5563', light: '#9CA3AF' },
          gray:   { border: '#E5E7EB', bg: '#F5F5F5', surface: '#FFFFFF' },
        },
        semantic: {
          success: { DEFAULT: '#22C55E', hover: '#16A34A', light: '#DCFCE7' },
          warning: { DEFAULT: '#EAB308', hover: '#CA8A04', light: '#FEF9C3' },
          danger:  { DEFAULT: '#EF4444', hover: '#DC2626', light: '#FEE2E2' },
          info:    { DEFAULT: '#3B82F6', light: '#DBEAFE' },
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        'display':  ['24px', { lineHeight: '32px', fontWeight: '700' }],
        'heading':  ['20px', { lineHeight: '28px', fontWeight: '600' }],
        'title':    ['18px', { lineHeight: '24px', fontWeight: '600' }],
        'subtitle': ['16px', { lineHeight: '22px', fontWeight: '600' }],
        'body':     ['14px', { lineHeight: '20px', fontWeight: '400' }],
        'small':    ['12px', { lineHeight: '16px', fontWeight: '400' }],
        'caption':  ['11px', { lineHeight: '14px', fontWeight: '400' }],
      },
      spacing: {
        'xs': '4px',  'sm': '8px',  'md': '16px',
        'lg': '24px', 'xl': '32px', '2xl': '48px', '3xl': '64px',
      },
      borderRadius: {
        'input': '6px',
        'card': '8px',
        'modal': '12px',
        'full': '9999px',
      },
      boxShadow: {
        'card': '0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06)',
        'modal': '0 10px 25px rgba(0,0,0,0.12)',
        'dropdown': '0 4px 6px rgba(0,0,0,0.07)',
      },
    },
  },
}
```

---

## 11. Regras de Responsividade

### 11.1 Breakpoints

| Nome | Largura | Dispositivo | Comportamento |
|------|---------|-------------|---------------|
| `sm` | ≥640px | Mobile landscape | Sidebar oculta, 1 coluna |
| `md` | ≥768px | Tablet | Sidebar compacta, 2 colunas |
| `lg` | ≥1024px | Desktop pequeno | Sidebar visível, tabelas completas |
| `xl` | ≥1280px | Desktop grande | Layout máximo 1400px centralizado |
| `2xl` | ≥1536px | Desktop ultrawide | Conteúdo máximo ~1400px (não estica) |

### 11.2 Comportamento por Componente

#### Sidebar

```
Desktop (≥1024px):                    Tablet (768-1023px):
┌──────┬──────────────────┐           ┌──┬──────────────────┐
│      │                  │           │☰ │                  │
│ SIDE │    CONTEÚDO      │           └──┴──────────────────┘
│ BAR  │                  │
│      │                  │           Sidebar em overlay
│      │                  │           quando aberta (☰)
│      │                  │
└──────┴──────────────────┘           Mobile (<768px):
                                      Sidebar fullscreen em overlay
```

#### Cards (StatCard)

```
Desktop (≥1024px):          Tablet (768-1023px):       Mobile (<768px):
┌────┐┌────┐┌────┐┌────┐    ┌──────┐┌──────┐          ┌──────────┐
│ C1 ││ C2 ││ C3 ││ C4 │    │  C1  ││  C2  │          │    C1    │
└────┘└────┘└────┘└────┘    ├──────┤├──────┤          ├──────────┤
4 colunas                    │  C3  ││  C4  │          │    C2    │
                            └──────┘└──────┘          ├──────────┤
                            2 colunas                 │    C3    │
                                                      ├──────────┤
                                                      │    C4    │
                                                      └──────────┘
                                                      1 coluna
```

#### Formulário (Nova OFS)

```
Desktop (≥1024px):                    Mobile (<1024px):
┌──────────────────────────────────┐  ┌──────────────────────┐
│ Empresa Observada: [_________▾]  │  │ Empresa Observada *  │
│                                  │  │ [________________▾]  │
│ Nome Observado:    [_________]   │  │                      │
│ Local:             [_________]   │  │ Nome do Observado *  │
│                                  │  │ [________________]   │
│ Atividade:         [_________]   │  │                      │
│                                  │  │ Local Observado *    │
│ Turno: [_______▾] Tipo: ○Positivo│  │ [________________]   │
│                      ●Negativo   │  │                      │
│                                  │  │ Atividade Observada* │
│ Comportamento:     [_________]   │  │ [________________]   │
│                   [_________]   │  │                      │
│                                  │  │ Turno *    Tipo *    │
│ Observação:        [_________]   │  │ [_______▾] ○Positivo │
│                                  │  │            ●Negativo │
│ [💾 SALVAR] [📄 PDF] [🗑] [✕]   │  │                      │
└──────────────────────────────────┘  │ Comportamento *      │
                                      │ [________________]   │
                                      │ [________________]   │
                                      │                      │
                                      │ Observação           │
                                      │ [________________]   │
                                      │                      │
                                      │ [💾 SALVAR]          │
                                      │ [📄 PDF]             │
                                      │ [🗑 LIMPAR]          │
                                      └──────────────────────┘
```

#### Gráficos (Métricas)

```
Desktop (≥1280px):              Tablet (768-1279px):       Mobile (<768px):
┌────────────┐┌────────────┐    ┌────────────────────┐    ┌────────────────────┐
│  Gráfico 1 ││  Gráfico 2 │    │     Gráfico 1      │    │     Gráfico 1      │
│            ││            │    └────────────────────┘    └────────────────────┘
└────────────┘└────────────┘    ┌────────────────────┐    ┌────────────────────┐
2 lado a lado                   │     Gráfico 2      │    │     Gráfico 2      │
┌──────────────────────────┐    └────────────────────┘    └────────────────────┘
│       Gráfico 3          │    1 por linha               1 por linha
│       (linha, full)      │
└──────────────────────────┘
full width
```

#### Tabelas

```
Desktop (≥768px):                    Mobile (<768px):
┌────┬──────────┬──────┬──────┐     ┌────────────────────────────┐
│ ID │ Nome     │Tipo  │Status│     │ OFS #1523                  │
├────┼──────────┼──────┼──────┤     │ João Silva                │
│1523│João Silva│Posit.│Gerado│     │ 13/05/2026 · Positivo·Gerad│
│1522│Maria S.  │Negat.│Gerado│     │ [👁] [📄] [✎]             │
└────┴──────────┴──────┴──────┘     ├────────────────────────────┤
Tabela completa                     │ OFS #1522                  │
com scroll horizontal               │ Maria Souza               │
se necessário                       │ 13/05/2026 · Negativo·Gerad│
                                    │ [👁] [📄] [✎]             │
                                    └────────────────────────────┘
                                    Cards empilhados
                                    (mobile-first para tabelas simples)
```

### 11.3 Regras de Toque (Mobile)

```
- Alvos de toque mínimos: 44×44px (WCAG)
- Espaçamento entre botões: mínimo 8px
- Sem hover states em mobile (usar active)
- Formulários: teclado correto para cada tipo de campo
  (text, email, number, tel)
- Swipe para fechar modais e sidebars
- Pull-to-refresh em listas (opcional)
```

---

## 12. Critérios de Aceite da Interface

### 12.1 Login

- [ ] Tela de login carrega em < 2 segundos
- [ ] Logo Security Dynamics visível e centralizado
- [ ] Campos de login e senha com labels claros
- [ ] Botão "Entrar" em vermelho institucional (#CC0000)
- [ ] Mensagem de erro aparece em vermelho abaixo do botão
- [ ] Ao errar 5 vezes, mensagem de bloqueio aparece
- [ ] Sessão expirada redireciona para login com mensagem
- [ ] Tecla Enter submete o formulário
- [ ] Foco automático no campo login ao carregar

### 12.2 Navegação

- [ ] Sidebar mostra apenas links permitidos pelo perfil
- [ ] Link ativo destacado com fundo cinza claro ou vermelho suave
- [ ] Header mostra nome do usuário logado
- [ ] Logout funciona e redireciona para login
- [ ] Botão voltar do navegador funciona corretamente
- [ ] Breadcrumb aparece em telas de detalhe

### 12.3 Nova OFS/OFS

- [ ] Formulário carrega em < 1 segundo
- [ ] Campos automáticos (código, data, hora, usuário) visíveis mas não editáveis
- [ ] Dropdown de empresas contém as 15 empresas + "Outros"
- [ ] Selecionar "Outros" exibe campo de nome da empresa (obrigatório)
- [ ] Validação em tempo real (ao perder o foco do campo)
- [ ] Campos obrigatórios marcados com asterisco (*)
- [ ] Botão "Salvar" desabilitado até preencher todos os obrigatórios
- [ ] Ao salvar: spinner no botão + desabilitar todos os campos
- [ ] Sucesso: redireciona para tela de confirmação com nº do OFS
- [ ] Tempo médio para preencher e salvar: < 2 minutos
- [ ] Funciona em tablet e celular (campos empilhados)

### 12.4 Consulta

- [ ] Todos os filtros carregam dropdowns corretamente
- [ ] Combinação de filtros funciona (AND lógico)
- [ ] Tabela mostra colunas: Código, Data, Observado, Empresa, Tipo, Status, Ações
- [ ] Paginação funciona (próxima, anterior, números)
- [ ] Ordenação por coluna clicando no cabeçalho
- [ ] "Limpar filtros" reseta todos os campos
- [ ] Observador vê apenas seus registros
- [ ] Supervisor vê registros do contrato
- [ ] Gestor/Admin veem todos

### 12.5 Métricas da Semana

- [ ] Cards de indicadores com números grandes e legíveis
- [ ] Status colorido: verde (OK), amarelo (ATENÇÃO), vermelho (ALERTA)
- [ ] Navegação entre semanas com setas funciona
- [ ] Filtros de contrato/empresa atualizam os dados
- [ ] 5 gráficos renderizados corretamente
- [ ] Gráficos responsivos (redimensionam)
- [ ] Tabela consolidada com todas as empresas/contratos
- [ ] Botões Exportar PDF e Imprimir visíveis

### 12.6 Relatórios

- [ ] Cards de tipos de relatório com descrição clara
- [ ] Seletores de parâmetros (semana, mês, contrato) funcionais
- [ ] Botão "Gerar PDF" mostra loading durante geração
- [ ] Download inicia automaticamente ao finalizar
- [ ] Histórico lista relatórios anteriores com download

### 12.7 Geral

- [ ] Nenhum erro de console (CORS, 404, dependência externa)
- [ ] Fonte Inter carrega localmente (sem Google Fonts)
- [ ] Ícones Lucide renderizam (sem CDN)
- [ ] Tempo de carregamento de cada tela < 3 segundos
- [ ] Layout responsivo testado em 1920px, 1366px, 1024px, 768px, 375px
- [ ] Contraste de texto atende WCAG AA (ratio ≥ 4.5:1)
- [ ] Navegação por teclado funciona (Tab, Enter, Esc)
- [ ] Estados de loading, empty e error implementados em todas as listas
- [ ] Toasts de feedback para todas as ações de escrita (criar, editar, cancelar)

---

**Documento gerado em 13/05/2026.**
