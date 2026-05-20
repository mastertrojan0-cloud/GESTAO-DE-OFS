# RELATÓRIO DE QUALIDADE — Sistema OFS

**Data:** 18/05/2026  
**Auditor:** Engenharia de Qualidade  
**Método:** 4 agentes em paralelo (Backend, Frontend, Banco, Funcional)  

---

## Sumário

| Área | Testes | Passou | Falhou |
|------|:---:|:---:|:---:|
| Backend (imports/APIs/regras) | 22 issues | — | 22 |
| Frontend (build/tipos/componentes) | 17 issues | — | 17 |
| Banco (schema/índices/dados) | 12 issues | — | 12 |
| Funcional ponta a ponta | 9 testes | 4 | 5 |

**Total: 60 issues — 6 CRITICAL, 14 HIGH, 16 MEDIUM, 24 LOW**

---

## ISSUES CRÍTICAS (6)

| # | Área | Issue | Impacto | Correção |
|---|------|-------|---------|----------|
| **C1** | API | `api/ofs_records.py:65` — parâmetros em ordem errada `create_ofs_record(payload, current_user, db)` vs serviço `create_ofs(db, data, current_user)` | **Criar OFS quebrado (500)** | Inverter parâmetros |
| **C2** | API | `api/ofs_records.py:98` — passa `page_size` mas serviço espera `limit` | **Listar OFS quebrado (500)** | Renomear parâmetro |
| **C3** | API | `api/metrics.py:116` — passa `(db, inicio, fim)` (dates) mas serviço espera `(db, year, week)` (ints) | **Métricas quebradas (500)** | Corrigir chamada |
| **C4** | Types | `types/index.ts:90,119` — `interface OFS` e `type OFS = OFS` duplicados | **Build TypeScript falha** | Remover linha 119 |
| **C5** | Front | `App.tsx:68` — `ProtectedRoute` sem `<Outlet/>`, admin routes renderizam branco | **Admin inacessível** | Adicionar Outlet ou reestruturar |
| **C6** | Banco | Zero Row-Level Security em `ofs_records` — qualquer usuário autenticado pode acessar registros de outras empresas se pular a aplicação | **Vazamento de dados** | Habilitar RLS |

---

## ISSUES ALTAS (14)

| # | Área | Issue | Correção |
|---|------|-------|----------|
| **H1** | API | Legacy `/api/ofs` router quebrado — atributos errados (`.data` vs `.data_registro`, `.tipo` vs `.tipo_observacao`, etc.) | Remover router legado ou reescrever |
| **H2** | API | `audit.py:38` — `AuditoriaLog.usuario_id` não existe, é `AuditoriaLog.user_id` | Corrigir nome da coluna |
| **H3** | API | `/api/users` e `/api/companies` não existem — 404 | Criar routers admin |
| **H4** | Front | 36 erros TypeScript — `tsc --noEmit` falha, produção não builda com `tsc -b` | Corrigir erros de tipo |
| **H5** | Front | `TipoOFS` comparado a strings erradas (`'OFS'`, `'Positivo (Seguro)'`) em 4 arquivos | Corrigir literais |
| **H6** | Form | "Outros" empresa não validado — campo `empresa_outros` pode ficar vazio | Adicionar validação |
| **H7** | Seg | Histórico de senhas não aplicado — `change_password` nunca verifica `password_history` | Implementar verificação |
| **H8** | Seg | `validate_password_strength` hardcoded 8, config `PASSWORD_MIN_LENGTH=12` ignorado | Usar `settings.PASSWORD_MIN_LENGTH` |
| **H9** | Erro | `app/main.py:57` — handler global de Exception engole erros de validação (422) como 500 | Remover ou restringir handler |
| **H10** | Banco | Tabela `contracts` vazia — FK de `contrato_id` falha se for NOT NULL | Inserir seed |
| **H11** | Banco | 8 índices redundantes (full + partial sobrepostos) em `ofs_records` | Remover índices duplicados |
| **H12** | Banco | Índice UNIQUE duplicado em `ofs_records.codigo` (2 btree indexes no mesmo) | Remover `uq_ofc_codigo` |
| **H13** | API | `ofs_records.py:124` — `result["page_size"]` não existe, é `result["limit"]` | Corrigir chave |
| **H14** | Form | `EditarOFCPage` — Select com valores iguais `{value:'OFS', label:'OFS'}` duplicado | Corrigir opções |

---

## ISSUES MÉDIAS (16)

| # | Área | Issue | Correção |
|---|------|-------|----------|
| M1 | API | `services/__init__.py` importa funções inexistentes `get_evolution`, `get_ranking` | Corrigir imports |
| M2 | DB | `core/audit.py` SQL raw escreve coluna `entity` mas tabela tem `resource` | Alinhar coluna |
| M3 | API | Dois routers OFS paralelos registrados (`/api/ofs` + `/api/ofs-records`) | Remover legado |
| M4 | Front | Arquivos duplicados: `*OFCPage.tsx` vs `*OFSPage.tsx` — App.tsx usa versão errada | Unificar nos `*OFS` |
| M5 | Front | `EditarOFCPage` — campo `comportamento` é Select mas deveria ser Textarea | Mudar para Textarea |
| M6 | Front | Sem componente Textarea reutilizável — usa `<textarea>` inline com Tailwind | Criar componente |
| M7 | Front | Toast sem auto-dismiss — fica até clique manual | Adicionar setTimeout |
| M8 | Forms | Campos required validados sem `.trim()` — espaços passam | Adicionar `.trim()` |
| M9 | API | `auth.py` — `LoginAttempt` criado sem `ip_address` e `user_agent` | Extrair do request |
| M10 | API | Sem rotas admin (users, companies, targets, contracts) implementadas | Criar `api/admin.py` |
| M11 | Banco | 19 índices com prefixo `ofc_` em tabelas `ofs_*` | Renomear índices |
| M12 | Banco | 17 constraints com prefixo `ofc_` em tabelas `ofs_*` | Renomear constraints |
| M13 | Banco | 3 triggers com prefixo `ofc_` | Renomear triggers |
| M14 | Banco | `system_params.nome_sistema = 'Sistema OFC/OFS'` — nome antigo | Atualizar para `Sistema OFS` |
| M15 | Seg | Middleware RBAC com case errado nas paths (`/api/OFS` vs `/api/ofs`) | Corrigir case |
| M16 | API | `api/ofs.py:49` — `hasattr(payload, 'empresa_observada_id')` sempre True (campo existe) | Usar `or` |

---

## ISSUES BAIXAS (24)

| # | Área | Issue |
|---|------|-------|
| L1 | Import | `models/__init__.py` não exporta `RefreshToken`, `LoginAttempt` |
| L2 | API | Vários endpoints sem `response_model` |
| L3 | Seg | `password_expires_at` nunca atualizado ao trocar senha |
| L4 | Erro | Decorator `@audit` engole exceções silenciosamente |
| L5 | Types | `TipoOFC` deprecated ainda exportado |
| L6-14 | Lint | 9 imports não usados em 8 arquivos |
| L15 | Banco | `ofs_records.codigo` nullable apesar de UNIQUE |
| L16 | Banco | Sem índice standalone em `is_deleted` |
| L17 | Banco | FK nome `ofc_edit_log_ofc_record_id_fkey` com duplo `ofc` |
| L18 | Rota | Sem página `/perfil` para alterar senha |
| L19 | Rota | Sem error boundary nas páginas |
| L20 | Front | Redirecionamento `window.location.href` em vez de React Router |
| L21 | Front | Formulário não centralizado em telas ultrawide |
| L22 | Front | `@/components/charts` sem barrel file (criado, mas verificar) |
| L23 | API | Sem `/api/reports/month/excel` |
| L24 | Docs | 40+ objetos com nome antigo `ofc_` no banco |

---

## PLANO DE CORREÇÃO (por prioridade)

### Fase 1 — CRÍTICO (30 min)
Corrigir 3 bugs que quebram funcionalidades core:

```
1. api/ofs_records.py:65  — inverter parâmetros create_ofs_record
2. api/ofs_records.py:98  — trocar page_size por limit  
3. api/metrics.py:116     — corrigir chamada calculate_weekly_metrics
```
**Validação:** Testes 5, 6, 7 do funcional devem passar.

### Fase 2 — TYPES + BUILD (20 min)
```
4. types/index.ts:119      — remover linha `type OFS = OFS`
5. Corrigir TipoOFS literals em 4 arquivos
6. Remover imports não usados (10 warnings)
```
**Validação:** `tsc --noEmit` deve passar com 0 erros.

### Fase 3 — ROTAS + FORM (30 min)
```
7. App.tsx:68              — corrigir ProtectedRoute admin
8. NovoOFSPage             — adicionar validação "Outros"
9. EditarOFCPage           — corrigir Select opções
10. Unificar *OFCPage → *OFSPage no App.tsx
```
**Validação:** Navegação admin funcional, formulário valida "Outros".

### Fase 4 — API + SEGURANÇA (40 min)
```
11. api/users + api/companies — criar routers admin
12. security.py:44         — usar settings.PASSWORD_MIN_LENGTH
13. security.py:214        — verificar histórico de senhas
14. main.py:57             — remover handler global de Exception
15. audit.py:38            — corrigir AuditoriaLog.user_id
```
**Validação:** Testes 3, 4 do funcional devem passar.

### Fase 5 — BANCO (30 min)
```
16. Inserir seed contract
17. Remover índice UNIQUE duplicado
18. Remover 8 índices redundantes
19. Atualizar system_params.nome_sistema
20. Habilitar RLS em ofs_records
```
**Validação:** `SELECT * FROM contracts` retorna > 0 linhas.

### Fase 6 — LIMPEZA (20 min)
```
21. Remover router legado /api/ofs
22. Renomear prefixos ofc_ → ofs_ no banco (opcional, cosmético)
23. Corrigir middleware RBAC case
```
**Validação:** `grep -r "OFC" backend/` retorna 0 resultados.
