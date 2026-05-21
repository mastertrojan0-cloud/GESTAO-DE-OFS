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

## Acesso pela rede local (LAN)

O Vite escuta em `0.0.0.0:3000` e o uvicorn sobe em `--host 0.0.0.0:8000`. Usuários cadastrados (admin → Cadastrar Usuário) fazem login normalmente pela rede local.

**Configuração rápida (uma vez, como administrador):**

```cmd
cd ofs-feedback
configurar_rede.bat
```

O script libera as portas **3000** (frontend) e **8000** (API) no Windows Firewall (perfis Private e Domain) e lista todos os IPs disponíveis para acesso.

Depois disso, qualquer máquina da LAN acessa em `http://<IP-DO-HOST>:3000`.

## Acesso remoto via Tailscale

Para acessar o sistema fora da rede local (home office, celular 4G/5G, outra unidade) sem expor o servidor à internet pública, use [Tailscale](https://tailscale.com):

1. **No servidor (host):**
   - Instale o Tailscale Windows: <https://tailscale.com/download/windows>
   - Faça login na sua tailnet.
   - Rode `configurar_rede.bat` como administrador — ele detecta o Tailscale e mostra o IP da tailnet (ex.: `http://100.x.y.z:3000`) e o nome MagicDNS (ex.: `http://servidor-ofs:3000`).

2. **Nos clientes (notebooks/celulares):**
   - Instale o Tailscale no dispositivo.
   - Faça login na mesma tailnet.
   - Acesse `http://<IP-TAILSCALE>:3000` ou `http://<nome-magicdns>:3000`.

**Vantagens:** túnel WireGuard criptografado ponta-a-ponta, sem precisar abrir portas no roteador, sem IP público, com ACLs por usuário/grupo na tailnet.

## 🚀 Setup (Primeira vez)

Se é a primeira vez rodando o sistema na máquina, execute como **administrador**:

```cmd
cd ofs-feedback
setup_primeira_vez.bat
```

Ele faz automaticamente:
1. ✅ Inicia PostgreSQL (se estiver parado)
2. ✅ Cria role `ofs_app` e database `ofs_db`
3. ✅ Carrega schema e seed (`ddl_sistema_ofs.sql`)
4. ✅ Instala dependências Node (`npm install`)

Roda **uma única vez** — depois cria um marcador em `%LOCALAPPDATA%\gestao_ofs.setup_ok` pra não repetir.

---

## Atalho na Área de Trabalho

Para deixar o sistema a um clique de distância, com ícone próprio (escudo azul com "OFS"):

```cmd
cd ofs-feedback
criar_atalho.bat
```

O script gera `ofs-feedback/assets/ofs.ico` (escudo circular azul, faixa verde, "OFS" em branco) e cria o atalho **GESTÃO DE OFS** na Área de Trabalho apontando para o `iniciar.bat`. Duplo clique sobe todo o sistema.

## Inicialização automática com o Windows

Para que o sistema suba sozinho toda vez que a máquina ligar:

1. Abra a pasta `ofs-feedback`.
2. Clique com o botão direito em **`instalar_autostart.bat`** → **Executar como administrador**.

O script registra uma **Tarefa Agendada** (`GESTAO_DE_OFS_Autostart`) que dispara no logon de qualquer usuário e executa `iniciar_silencioso.vbs`, subindo PostgreSQL, FastAPI e o servidor frontend em background (sem janela de console).

**Para testar agora sem reiniciar:**

```cmd
schtasks /Run /TN "GESTAO_DE_OFS_Autostart"
```

**Para remover o autostart:** rode `desinstalar_autostart.bat` como administrador.

### Scripts disponíveis em `ofs-feedback/`

| Script | Função |
|---|---|
| `setup_primeira_vez.bat` | PostgreSQL + role + database + schema + npm (roda uma única vez) |
| `criar_atalho.bat` | Gera ícone customizado e atalho **GESTÃO DE OFS** na Área de Trabalho |
| `iniciar.bat` | Sobe tudo manualmente com painel de controle interativo |
| `iniciar_silencioso.vbs` | Sobe tudo em background (sem janela) — usado pelo autostart |
| `instalar_autostart.bat` | Registra tarefa agendada de logon (admin) |
| `desinstalar_autostart.bat` | Remove a tarefa agendada (admin) |
| `configurar_rede.bat` | Libera firewall 3000/8000 e mostra IPs LAN + Tailscale (admin) |
| `stop.bat` | Para todos os serviços |

## Changelog recente

- **2026-05-21** — Inicialização automática com o Windows via Agendador de Tarefas (`instalar_autostart.bat` + `iniciar_silencioso.vbs`); configuração de firewall e suporte a acesso remoto via Tailscale (`configurar_rede.bat`); atalho na Área de Trabalho com ícone customizado escudo OFS (`criar_atalho.bat`); **setup de primeira vez** que cria role PostgreSQL, database e carrega schema automaticamente (`setup_primeira_vez.bat`).
- **2026-05-20** — Sigla unificada para OFS (remoção total de "OFC" do layout); bandeiras SVG; campo "Nome do Observado" removido dos formulários (enviado automaticamente como "Não informado"); módulo de cadastro de usuários visível na sidebar; nome do sistema padronizado para "GESTÃO DE OFS"; copyright Antonio Martinez; acesso LAN habilitado.
