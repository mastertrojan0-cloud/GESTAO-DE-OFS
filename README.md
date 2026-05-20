# GESTÃO DE OFS

Sistema de Feedback Comportamental — registro e análise de OFS (Observações de Feedback de Segurança).

🇻🇪 🇧🇷 © Antonio Martinez

---

## Visão geral

Aplicação web full-stack para que observadores cadastrem, em tempo real, ocorrências de comportamento seguro/inseguro no ambiente operacional, e para que gestores acompanhem métricas semanais, aderência e consolidados por empresa.

**Regra de classificação única:** uma OFS é sempre **Positiva (Seguro)** ou **Negativa (Inseguro)** — não existem outras categorias.

## Stack

- **Frontend:** React 18 + Vite + TypeScript + TailwindCSS + Zustand + React Router
- **Backend:** FastAPI (Python) + SQLAlchemy + PostgreSQL
- **Auth:** JWT (access + refresh) com renovação automática

## Estrutura

```
SISTEMA OFS/
├── ofs-feedback/              # Aplicação principal
│   ├── src/                   # Frontend (React + TS)
│   │   ├── pages/             # Telas (OFS, admin, métricas, etc.)
│   │   ├── components/        # UI reutilizável (Flag, Button, Table, ...)
│   │   ├── stores/            # Zustand (auth, ofsStore, metricas)
│   │   └── lib/               # api, empresasFallback, utils
│   ├── backend/               # Backend FastAPI
│   │   ├── app/               # rotas, schemas, services
│   │   └── migrations/        # SQL de schema e seed
│   ├── vite.config.ts         # Vite (host 0.0.0.0 para acesso LAN)
│   └── package.json
├── ddl_sistema_ofs.sql        # DDL consolidada
├── ESPECIFICACAO_*.md         # Documentação técnica
└── README.md                  # Este arquivo
```

## Como rodar

### Frontend (desenvolvimento)

```bash
cd ofs-feedback
npm install
npm run dev
```

Servidor sobe em `http://0.0.0.0:3000` — acessível pela rede local em `http://<IP-DO-HOST>:3000`. Lembre de liberar a porta 3000 no firewall.

### Build de produção

```bash
npm run build      # gera dist/
npm run preview    # serve dist/ em 0.0.0.0:3000
```

### Backend

```bash
cd ofs-feedback/backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Funcionalidades

### Operação (todos os perfis)
- **Dashboard** — resumo do dia/semana, taxa positiva/negativa
- **Nova OFS** — registro rápido (atividade, local, empresa, turno, tipo, comportamento)
- **Lista de OFSs** — busca + filtros (data, tipo, status, turno)
- **Consulta Avançada** — filtros completos + exportação CSV
- **Detalhe / Editar OFS** — visualização + edição com histórico

### Gestão (supervisor/gestor/admin)
- **Métricas** — aderência, % seguro, programado vs realizado, gráficos por empresa, evolução semanal
- **Relatórios** — semanal, mensal, por empresa, individual

### Administração (admin)
- **Usuários** — listagem + filtro por perfil
- **Cadastrar Usuário** — formulário com username/senha (mín. 8 chars), perfil, empresa, status
- **Empresas, Contratos, Metas, Auditoria, Backup**

## Identidade visual

- Nome do produto: **GESTÃO DE OFS**
- Bandeiras 🇻🇪 (Venezuela) e 🇧🇷 (Brasil) renderizadas como SVG inline (`src/components/ui/Flag.tsx`) — visíveis no Header, Sidebar e Login em qualquer SO
- Copyright: `© {ano} Antonio Martinez`

## Lista de empresas (fonte da verdade)

14 empresas disponíveis no select (Security Dynamics é excluída por ser operadora interna):

Polo Norte · G4S · ERA · Innovatec · Conin · FM · Sodexo · Engecom · P&G · Yusen · Mainpower · Aduana · Prosegur · Outros

Fallback estático em `src/lib/empresasFallback.ts` — usado automaticamente caso o backend não responda.

## Perfis e permissões

| Perfil | Pode |
|---|---|
| `observador` | Criar OFS, editar as próprias enquanto ativas |
| `supervisor` | Tudo do observador + editar OFSs da sua empresa, ver métricas |
| `gestor` | Tudo do supervisor + cancelar OFSs, relatórios |
| `admin` | Tudo + cadastrar usuários, empresas, contratos, metas, auditoria, backup |

## Valores enum (backend) — não alterar sem migração

- `TipoObservacao`: `"Positivo/Seguro"` / `"Negativo/Inseguro"` (label exibido como **OFS Positiva (Seguro)** / **OFS Negativa (Inseguro)**)
- `Turno`: ADM, 1, 2, 3
- `StatusRegistro`: Gerado, Editado, Cancelado

## Acesso pela rede local

O Vite escuta em `0.0.0.0:3000` e o uvicorn deve subir com `--host 0.0.0.0`. Usuários cadastrados (admin → Cadastrar Usuário) fazem login normalmente pela rede local.

## Changelog recente

- **2026-05-20** — Sigla unificada para OFS (remoção total de "OFC" do layout); bandeiras SVG; campo "Nome do Observado" removido dos formulários (enviado automaticamente como "Não informado"); módulo de cadastro de usuários visível na sidebar; nome do sistema padronizado para "GESTÃO DE OFS"; copyright Antonio Martinez; acesso LAN habilitado.
