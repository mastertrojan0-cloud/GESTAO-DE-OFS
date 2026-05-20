# ARQUITETURA DE INFRAESTRUTURA, DEPLOY E SEGURANÇA

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Arquitetura Completa da Infraestrutura](#1-arquitetura-completa-da-infraestrutura)
2. [Fluxo do Ambiente](#2-fluxo-do-ambiente)
3. [Diagrama Textual dos Serviços](#3-diagrama-textual-dos-serviços)
4. [Estratégia Docker](#4-estratégia-docker)
5. [Estrutura de Diretórios](#5-estrutura-de-diretórios)
6. [Estratégia PostgreSQL](#6-estratégia-postgresql)
7. [Estratégia de Backup](#7-estratégia-de-backup)
8. [Estratégia de Segurança](#8-estratégia-de-segurança)
9. [Estratégia de Auditoria](#9-estratégia-de-auditoria)
10. [Estratégia de Logs](#10-estratégia-de-logs)
11. [Estratégia de PDF](#11-estratégia-de-pdf)
12. [Estratégia de Gráficos](#12-estratégia-de-gráficos)
13. [Estratégia de Escalabilidade Futura](#13-estratégia-de-escalabilidade-futura)
14. [Estratégia de Migração para Nuvem](#14-estratégia-de-migração-para-nuvem)
15. [Estratégia de Atualização](#15-estratégia-de-atualização)
16. [Estratégia de Monitoramento](#16-estratégia-de-monitoramento)
17. [Requisitos Mínimos do Servidor](#17-requisitos-mínimos-do-servidor)
18. [Checklist de Implantação do Ambiente](#18-checklist-de-implantação-do-ambiente)

---

## 1. Arquitetura Completa da Infraestrutura

### 1.1 Visão Geral — Camada Física

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SERVIDOR INTERNO (On-Premise)                     │
│                                                                      │
│  Sistema Operacional: Ubuntu Server 22.04 LTS (ou Windows Server)    │
│  CPU: 4 vCPUs | RAM: 8 GB | DISCO: 100 GB SSD                       │
│  Rede: IP fixo na rede local (ex: 192.168.1.100)                     │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                      DOCKER ENGINE                              │ │
│  │                                                                  │ │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌───────────┐ │ │
│  │  │   nginx    │  │  backend   │  │ postgresql │  │  backup   │ │ │
│  │  │  :80:443   │─▶│  :8000     │─▶│  :5432     │  │  cron     │ │ │
│  │  │            │  │            │  │            │  │           │ │ │
│  │  │ serve      │  │ FastAPI    │  │ dados      │  │ pg_dump   │ │ │
│  │  │ estáticos  │  │ Uvicorn    │  │ métricas   │  │ diário    │ │ │
│  │  │ + proxy    │  │ WeasyPrint │  │ auditoria  │  │ 03:00 AM  │ │ │
│  │  └────────────┘  └────────────┘  └────────────┘  └───────────┘ │ │
│  │                                                                  │ │
│  │  VOLUMES PERSISTENTES:                                           │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐  │ │
│  │  │ pgdata   │  │ backups  │  │ reports  │  │ logs           │  │ │
│  │  │ (banco)  │  │ (.dump)  │  │ (PDFs)   │  │ (nginx+app)    │  │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                   REDE LOCAL (192.168.x.x)                       │ │
│  │                                                                  │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │ │
│  │  │ Desktop  │  │ Desktop  │  │ Tablet   │  │ Smartphone   │   │ │
│  │  │ Operador │  │ Gestor   │  │ Campo    │  │ Supervisor   │   │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Visão Lógica — Camadas de Software

```
┌─────────────────────────────────────────────────────────────────┐
│                      CAMADA DE APRESENTAÇÃO                      │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  React 18 + Vite 5 + TypeScript                            │ │
│  │  • Tailwind CSS 3 (estilização)                            │ │
│  │  • Recharts (gráficos interativos)                         │ │
│  │  • Zustand (estado global)                                 │ │
│  │  • React Router v6 (roteamento)                            │ │
│  │  • Axios (HTTP client)                                     │ │
│  │                                                            │ │
│  │  Build → dist/ (HTML + JS + CSS estáticos)                 │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │ HTTP (REST API)
┌──────────────────────────────▼──────────────────────────────────┐
│                      CAMADA DE APLICAÇÃO                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  FastAPI 0.111+ (Python 3.12) + Uvicorn                    │ │
│  │                                                            │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │ │
│  │  │ Auth     │ │ OFS CRUD │ │ Metrics  │ │ Reports/PDF  │ │ │
│  │  │ JWT      │ │ Validação│ │ Cálculo  │ │ WeasyPrint   │ │ │
│  │  │ bcrypt   │ │ RBAC     │ │ Cache    │ │ matplotlib   │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │ │
│  │  │ Users    │ │ Consulta │ │ Audit    │ │ Backup       │ │ │
│  │  │ Admin    │ │ FTS      │ │ Log      │ │ APScheduler  │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │ │
│  │                                                            │ │
│  │  ORM: SQLAlchemy 2.0 (async) + Alembic (migrações)        │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │ SQL (asyncpg)
┌──────────────────────────────▼──────────────────────────────────┐
│                      CAMADA DE DADOS                             │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  PostgreSQL 16                                              │ │
│  │  • 11 tabelas (empresas, usuarios, contratos, locais,       │ │
│  │    metas_semanais, ofc_registros, ofc_edicoes,              │ │
│  │    auditoria, relatorios_gerados, backups, tokens_revogados)│ │
│  │  • Índices B-TREE + GIN (full-text search)                  │ │
│  │  • Triggers automáticos (datas, meta programada)            │ │
│  │  • Views materializadas (métricas pré-calculadas)           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  ARMAZENAMENTO DE ARQUIVOS                                  │ │
│  │  • /app/reports/ → PDFs gerados (volume Docker)            │ │
│  │  • /backups/     → Backups .dump (volume Docker)           │ │
│  │  • /app/logs/    → Logs de aplicação (volume Docker)       │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Comunicação Entre Serviços

```
┌───────────────────────────────────────────────────────────────────┐
│                                                                   │
│  Usuário (Browser)                                                 │
│       │                                                           │
│       │ http://192.168.1.100:80                                   │
│       ▼                                                           │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  NGINX (:80)                                              │    │
│  │                                                           │    │
│  │  location / {              → serve /usr/share/nginx/html  │    │
│  │    (SPA React: index.html + JS/CSS/assets)                │    │
│  │  }                                                        │    │
│  │                                                           │    │
│  │  location /api/ {          → proxy_pass backend:8000      │    │
│  │    (Todas as chamadas REST)                               │    │
│  │  }                                                        │    │
│  │                                                           │    │
│  │  location /api/relatorios/*/download {                    │    │
│  │    proxy_read_timeout 300s  (PDFs grandes)                │    │
│  │  }                                                        │    │
│  └──────────────────────────────────────────────────────────┘    │
│       │                                                           │
│       │ Rede Docker interna (bridge network: ofs-network)         │
│       ▼                                                           │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  BACKEND (FastAPI :8000)                                  │    │
│  │                                                           │    │
│  │  Conexão com banco:                                       │    │
│  │  postgresql+asyncpg://ofs_user:${DB_PASSWORD}@db:5432/ofs │    │
│  │                                                           │    │
│  │  Volumes montados:                                        │    │
│  │  ./reports → /app/reports    (PDFs gerados)               │    │
│  │  ./backups → /backups        (acesso ao pg_dump)          │    │
│  │  ./logs    → /app/logs       (logs da aplicação)          │    │
│  └──────────────────────────────────────────────────────────┘    │
│       │                                                           │
│       ▼                                                           │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  POSTGRESQL (:5432)                                       │    │
│  │  Volume: pgdata → /var/lib/postgresql/data                │    │
│  └──────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
```

---

## 2. Fluxo do Ambiente

### 2.1 Requisição Típica (Registro de OFS)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Browser  │───▶│  Nginx   │───▶│ FastAPI  │───▶│PostgreSQL│
│ (React)  │    │  :80     │    │  :8000   │    │  :5432   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
     │ POST /api/OFS │ proxy_pass    │               │
     │ Authorization │ /api/ →       │               │
     │ Bearer <jwt>  │ backend:8000  │               │
     │               │               │               │
     │               │               │ 1. Valida JWT │
     │               │               │ 2. Valida body│
     │               │               │ 3. Aplica RBAC│
     │               │               │               │
     │               │               │ 4. INSERT ───▶│
     │               │               │ ◀────── OK ───│
     │               │               │               │
     │               │               │ 5. Audit log  │
     │               │               │ 6. Response   │
     │               │ ◀─────────────│               │
     │ ◀─────────────│               │               │
     │               │               │               │
     │ Toast: "OFS #1523 criada!"    │               │
```

### 2.2 Geração de PDF (Métricas da Semana)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Browser  │───▶│  Nginx   │───▶│ FastAPI  │───▶│PostgreSQL│───▶│WeasyPrint│
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
     │                               │               │               │
     │ POST /api/relatorios/gerar    │               │               │
     │                               │ 1. Busca dados│              │
     │                               │──────────────▶│              │
     │                               │◀──────────────│              │
     │                               │                              │
     │                               │ 2. Gera PNGs (matplotlib)    │
     │                               │ 3. Renderiza HTML (Jinja2)   │
     │                               │                              │
     │                               │ 4. Converte HTML→PDF ───────▶│
     │                               │◀─────── PDF bytes ───────────│
     │                               │                              │
     │                               │ 5. Salva em /app/reports/    │
     │                               │ 6. Registra em relatorios    │
     │                               │ 7. Audit log                │
     │                               │                              │
     │ ◀─────── download_url ────────│                              │
     │                               │                              │
     │ GET /api/relatorios/:id/download                             │
     │ ◀─────── PDF stream ─────────│                              │
```

### 2.3 Backup Automático Diário

```
┌───────────────────────────────────────────────────────────────────┐
│  APScheduler (dentro do container backend)                         │
│                                                                   │
│  Cron: 0 3 * * *  (03:00 AM diariamente)                          │
│                                                                   │
│  1. Executa: pg_dump -h db -U ofs_user -d ofs_db \                │
│              -Fc -f /backups/backup_20260513_030000.dump           │
│                                                                   │
│  2. Verifica: pg_restore --list (integridade)                     │
│                                                                   │
│  3. Registra na tabela backups:                                    │
│     { nome, caminho, tamanho, tipo='auto', status='sucesso' }     │
│                                                                   │
│  4. Rotação: mantém últimos 30 backups, remove antigos            │
│                                                                   │
│  5. Copia para NAS (se configurado):                               │
│     cp /backups/backup_*.dump /mnt/nas/backups-ofs/               │
└───────────────────────────────────────────────────────────────────┘
```

---

## 3. Diagrama Textual dos Serviços

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DOCKER HOST                                   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Rede: ofs-network (bridge)                 │   │
│  │                                                               │   │
│  │  ┌──────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │    nginx         │  │         backend                   │  │   │
│  │  │                  │  │                                  │  │   │
│  │  │ Image: nginx:    │  │ Image: ofs-backend:latest        │  │   │
│  │  │   alpine         │  │ Build: backend/Dockerfile        │  │   │
│  │  │                  │  │                                  │  │   │
│  │  │ Ports:           │  │ Ports: 8000 (interna)            │  │   │
│  │  │  80:80           │  │                                  │  │   │
│  │  │  443:443 (futuro)│  │ Depende: db (healthy)            │  │   │
│  │  │                  │  │                                  │  │   │
│  │  │ Volumes:         │  │ Volumes:                         │  │   │
│  │  │  ./nginx/conf.d  │  │  ./reports:/app/reports          │  │   │
│  │  │  frontend/dist:  │  │  ./backups:/backups              │  │   │
│  │  │    /usr/share/   │  │  ./logs:/app/logs                │  │   │
│  │  │    nginx/html    │  │  ./backend/static:/app/static:ro │  │   │
│  │  │                  │  │                                  │  │   │
│  │  │ Healthcheck:     │  │ Healthcheck:                     │  │   │
│  │  │  curl localhost  │  │  curl localhost:8000/health      │  │   │
│  │  │                  │  │                                  │  │   │
│  │  │ Restart:         │  │ Restart: unless-stopped          │  │   │
│  │  │  unless-stopped  │  │                                  │  │   │
│  │  └──────────────────┘  └──────────────────────────────────┘  │   │
│  │                                                               │   │
│  │  ┌──────────────────┐  ┌──────────────────────────────────┐  │   │
│  │  │      db          │  │         (backup job)              │  │   │
│  │  │                  │  │                                  │  │   │
│  │  │ Image:           │  │ Executado pelo APScheduler       │  │   │
│  │  │  postgres:16-    │  │ DENTRO do container backend      │  │   │
│  │  │  alpine          │  │                                  │  │   │
│  │  │                  │  │ Cron: 0 3 * * *                  │  │   │
│  │  │ Ports:           │  │ Ação: pg_dump → /backups/        │  │   │
│  │  │  5432 (interna)  │  │                                  │  │   │
│  │  │                  │  │ Volume: ./backups:/backups        │  │   │
│  │  │ Env:             │  │  (compartilhado com backend)     │  │   │
│  │  │  POSTGRES_DB=    │  │                                  │  │   │
│  │  │    ofs_db        │  └──────────────────────────────────┘  │   │
│  │  │  POSTGRES_USER=  │                                         │   │
│  │  │    ofs_user      │                                         │   │
│  │  │  POSTGRES_PASS=  │                                         │   │
│  │  │    ${DB_PASSWORD}│                                         │   │
│  │  │                  │                                         │   │
│  │  │ Volume:          │                                         │   │
│  │  │  pgdata:/var/lib │                                         │   │
│  │  │  /postgresql/data│                                         │   │
│  │  │                  │                                         │   │
│  │  │ Healthcheck:     │                                         │   │
│  │  │  pg_isready      │                                         │   │
│  │  │                  │                                         │   │
│  │  │ Restart:         │                                         │   │
│  │  │  unless-stopped  │                                         │   │
│  │  └──────────────────┘                                         │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Estratégia Docker

### 4.1 docker-compose.yml (Produção)

```yaml
version: "3.9"

services:
  # ============================================================
  # NGINX — Reverse Proxy + Arquivos Estáticos
  # ============================================================
  nginx:
    image: nginx:1.25-alpine
    container_name: ofs-nginx
    ports:
      - "80:80"
      # - "443:443"  # Futuro: HTTPS com certificado interno
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./frontend/dist:/usr/share/nginx/html:ro
      - ./nginx/logs:/var/log/nginx
    networks:
      - ofs-network
    depends_on:
      backend:
        condition: service_started
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:80"]
      interval: 30s
      timeout: 5s
      retries: 3

  # ============================================================
  # BACKEND — FastAPI + Uvicorn
  # ============================================================
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    image: ofs-backend:latest
    container_name: ofs-backend
    ports:
      - "8000:8000"  # Exposto apenas para debug local; em produção, remover
    env_file:
      - .env
    environment:
      - DATABASE_URL=postgresql+asyncpg://ofs_user:${DB_PASSWORD}@db:5432/ofs_db
      - JWT_SECRET=${JWT_SECRET}
      - JWT_ALGORITHM=HS256
      - JWT_ACCESS_EXPIRE_MINUTES=15
      - JWT_REFRESH_EXPIRE_DAYS=7
      - REPORTS_DIR=/app/reports
      - BACKUP_DIR=/backups
      - LOG_DIR=/app/logs
      - LOG_LEVEL=INFO
    volumes:
      - ./reports:/app/reports      # PDFs gerados
      - ./backups:/backups          # Backups do banco
      - ./logs:/app/logs            # Logs da aplicação
      - ./backend/static:/app/static:ro  # Assets (logo, fontes)
    networks:
      - ofs-network
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
    # Segurança
    read_only: false  # Precisa escrever PDFs e logs
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE

  # ============================================================
  # POSTGRESQL — Banco de Dados
  # ============================================================
  db:
    image: postgres:16-alpine
    container_name: ofs-db
    environment:
      POSTGRES_DB: ofs_db
      POSTGRES_USER: ofs_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d:ro  # Scripts de inicialização
    networks:
      - ofs-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ofs_user -d ofs_db"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    # Segurança
    read_only: false
    security_opt:
      - no-new-privileges:true

networks:
  ofs-network:
    driver: bridge
    name: ofs-network

volumes:
  pgdata:
    name: ofs-pgdata
  # reports, backups, logs são bind mounts (pastas no host)
```

### 4.2 Dockerfile do Backend (Multi-stage)

```dockerfile
# ============================================================
# ESTÁGIO 1: Download de dependências (com internet)
# ============================================================
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip download -r requirements.txt -d /offline-packages

# ============================================================
# ESTÁGIO 2: Imagem final (offline)
# ============================================================
FROM python:3.12-slim

# Dependências de sistema para WeasyPrint + PostgreSQL
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-dejavu-core \
    fonts-liberation \
    postgresql-client-15 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Usuário não-root
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Instala dependências Python offline
COPY --from=builder /offline-packages /offline-packages
COPY requirements.txt .
RUN pip install --no-index --find-links /offline-packages -r requirements.txt \
    && rm -rf /offline-packages

# Fontes Inter (locais)
COPY static/fonts/ /usr/share/fonts/truetype/inter/
RUN fc-cache -fv

# Código da aplicação
COPY . .

# Diretórios com permissão de escrita
RUN mkdir -p /app/reports /app/logs \
    && chown -R appuser:appuser /app

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "4", "--log-level", "info"]
```

### 4.3 Dockerfile do Frontend

```dockerfile
# ============================================================
# ESTÁGIO 1: Build do Frontend
# ============================================================
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --prefer-offline
COPY . .
RUN npm run build

# O output dist/ é copiado para o nginx via volume bind mount
# ou via COPY no Dockerfile do nginx.
# Para MVP, recomendamos bind mount (docker-compose volume).
```

### 4.4 Configuração do Nginx

```nginx
# nginx/nginx.conf

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "same-origin" always;

    server {
        listen 80;
        server_name _;
        client_max_body_size 50M;

        # ==========================================
        # Frontend Estático (React build)
        # ==========================================
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;

            # Cache de assets com hash (1 ano)
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }
        }

        # ==========================================
        # API Backend
        # ==========================================
        location /api/ {
            proxy_pass http://backend:8000;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 120s;
            proxy_send_timeout 120s;
        }

        # Download de relatórios (timeout maior)
        location /api/relatorios/ {
            proxy_pass http://backend:8000;
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
        }

        # ==========================================
        # Health Check
        # ==========================================
        location /health {
            proxy_pass http://backend:8000/health;
            access_log off;
        }
    }
}
```

### 4.5 Estratégia de Volumes Persistentes

| Volume | Tipo | Host Path | Container Path | Propósito | Backup? |
|--------|------|-----------|----------------|-----------|:---:|
| `pgdata` | Volume Docker | (gerenciado pelo Docker) | `/var/lib/postgresql/data` | Dados do banco | ✅ |
| `reports` | Bind mount | `./reports` | `/app/reports` | PDFs gerados | ✅ |
| `backups` | Bind mount | `./backups` | `/backups` | Backups .dump | ✅ |
| `logs` | Bind mount | `./logs` | `/app/logs` | Logs da aplicação | Opcional |
| `static` | Bind mount (ro) | `./backend/static` | `/app/static` | Logo, fontes | ❌ (código) |
| `frontend` | Bind mount (ro) | `./frontend/dist` | `/usr/share/nginx/html` | Build frontend | ❌ (código) |
| `nginx_conf` | Bind mount (ro) | `./nginx` | `/etc/nginx` | Configuração | ✅ |

### 4.6 Estratégia de Restart Automático

```yaml
# Todos os serviços:
restart: unless-stopped

# Comportamento:
# - Container reinicia automaticamente se:
#   ❌ Processo principal morrer
#   ❌ Healthcheck falhar (após retries)
#   ❌ Docker daemon reiniciar
# - NÃO reinicia se parado manualmente (docker compose stop)
```

---

## 5. Estrutura de Diretórios

### 5.1 Diretórios no Servidor

```
/opt/sistema-ofs/                       ← Raiz do projeto no servidor
│
├── docker-compose.yml                  ← Orquestração principal
├── docker-compose.override.yml         ← Dev (hot-reload, portas debug)
├── .env                                 ← Variáveis de ambiente (NUNCA COMMITAR)
├── .env.example                         ← Template de .env
├── Makefile                             ← Comandos de operação
├── README.md                            ← Documentação de deploy
│
├── frontend/                            ← Código fonte React + Vite
│   ├── src/
│   ├── public/
│   ├── dist/                            ← Build de produção (gerado)
│   ├── package.json
│   └── vite.config.ts
│
├── backend/                             ← Código fonte FastAPI
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── alembic.ini
│   ├── alembic/                         ← Migrações
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── api/
│   │   ├── services/
│   │   └── core/
│   ├── templates/                       ← Templates Jinja2 (PDF)
│   │   └── reports/
│   └── static/                          ← Assets locais
│       ├── fonts/
│       │   ├── Inter-Regular.woff2
│       │   ├── Inter-SemiBold.woff2
│       │   └── Inter-Bold.woff2
│       └── logos/
│           └── security-dynamics.png
│
├── nginx/                               ← Configuração Nginx
│   ├── nginx.conf
│   └── conf.d/
│
├── db/                                  ← Scripts de banco
│   └── init/                            ← Scripts executados na criação
│       └── 01-extensions.sql
│
├── reports/                             ← PDFs gerados (volume)
│   └── .gitkeep
│
├── backups/                             ← Backups do banco (volume)
│   └── .gitkeep
│
├── logs/                                ← Logs da aplicação (volume)
│   ├── nginx/
│   └── app/
│
├── scripts/                             ← Scripts de manutenção
│   ├── deploy.sh                        ← Deploy inicial / atualização
│   ├── backup-manual.sh                 ← Backup manual
│   ├── restore.sh                       ← Restauração de backup
│   ├── health-check.sh                  ← Verificação de saúde
│   └── rotate-logs.sh                   ← Rotação de logs
│
└── docs/                                ← Documentação
    ├── PLANO_MESTRE_SISTEMA_OFS.md
    ├── PLANO_TECNICO_MVP_OFS.md
    ├── MODELAGEM_TECNICA_BD_API_MVP.md
    ├── ESPECIFICACAO_UX_UI_MVP.md
    ├── ESPECIFICACAO_RELATORIOS_PDF_MVP.md
    └── ARQUITETURA_INFRA_DEPLOY.md      ← Este documento
```

### 5.2 Arquivo .env (Exemplo)

```bash
# ========================================
# Sistema OFS/OFS — Security Dynamics
# Configuração de Ambiente
# ========================================

# Ambiente
AMBIENTE=producao
DEBUG=false

# Banco de Dados
DB_HOST=db
DB_PORT=5432
DB_NAME=ofs_db
DB_USER=ofs_user
DB_PASSWORD=SenhaForteSegura123!@#

# JWT
JWT_SECRET=chave-secreta-com-minimo-32-caracteres-aleatorios-aqui
JWT_ALGORITHM=HS256
JWT_ACCESS_EXPIRE_MINUTES=15
JWT_REFRESH_EXPIRE_DAYS=7

# CORS
CORS_ORIGINS=http://localhost:3000,http://192.168.1.100

# Relatórios
REPORTS_DIR=/app/reports
MAX_REPORT_SIZE_MB=50

# Backup
BACKUP_DIR=/backups
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE_HOUR=3
BACKUP_SCHEDULE_MINUTE=0

# Logging
LOG_LEVEL=INFO
LOG_DIR=/app/logs

# Admin padrão (seed)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=Admin@123
```

---

## 6. Estratégia PostgreSQL

### 6.1 Configuração Inicial

```ini
# postgresql.conf (valores ajustados)

# Conexões
max_connections = 50                   # Suficiente para MVP (10-50 usuários)
shared_buffers = 256MB                 # 25% da RAM (servidor 8GB)
work_mem = 16MB                        # Para sorts e hash tables
maintenance_work_mem = 64MB           # Para VACUUM e CREATE INDEX

# Planner
effective_cache_size = 2GB            # ~75% da RAM
random_page_cost = 1.1               # SSD (default 4.0 é para HDD)

# WAL (Write-Ahead Log)
wal_level = replica                    # Permite replicação futura
max_wal_size = 1GB
min_wal_size = 200MB

# Autovacuum (crítico para tabela de alto volume)
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 60s
autovacuum_vacuum_scale_factor = 0.05  # Mais agressivo (5% de mudanças)
autovacuum_analyze_scale_factor = 0.02

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000      # Log queries > 1 segundo
```

### 6.2 Índices (Já definidos na Modelagem Técnica)

```sql
-- Índices essenciais (resumo)
-- ofc_registros: data, empresa, tipo, usuário, status, turno
-- ofc_registros: composto para métricas (contrato_id, data, tipo)
-- ofc_registros: GIN full-text search (português)
-- usuarios: login, perfil, empresa
-- auditoria: timestamp DESC, usuário + timestamp
-- metas: contrato + ano + semana (único)
```

### 6.3 Estratégia de Vacuum

```sql
-- Tabela ofc_registros: alto volume de inserts
ALTER TABLE ofc_registros SET (
    autovacuum_vacuum_scale_factor = 0.01,   -- Vacuum após 1% de mudanças
    autovacuum_analyze_scale_factor = 0.005, -- Analyze após 0.5%
    autovacuum_vacuum_cost_limit = 1000,
    fillfactor = 85                          -- 15% livre para updates
);
```

### 6.4 Estratégia de Conexões (Pooling)

```
MVP (agora):
  SQLAlchemy pool: min=5, max=20, overflow=10
  Total máximo: 30 conexões
  Suficiente para 10-50 usuários simultâneos

Futuro (nuvem):
  pgBouncer entre backend e PostgreSQL
  Pool modo transação
  Reduz de 30 para ~10 conexões persistentes
```

---

## 7. Estratégia de Backup

### 7.1 Política de Backup

```
┌─────────────────────────────────────────────────────────────────────┐
│                        POLÍTICA DE BACKUP                            │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ TIPO          │ FREQUÊNCIA │ HORÁRIO │ RETENÇÃO             │    │
│  ├───────────────┼────────────┼─────────┼──────────────────────┤    │
│  │ Backup diário │ Diário     │ 03:00   │ 30 dias              │    │
│  │ (automático)  │            │         │                      │    │
│  ├───────────────┼────────────┼─────────┼──────────────────────┤    │
│  │ Backup semanal│ Domingo    │ 03:00   │ 12 semanas           │    │
│  │ (automático)  │            │         │                      │    │
│  ├───────────────┼────────────┼─────────┼──────────────────────┤    │
│  │ Backup mensal │ Dia 1      │ 03:00   │ 12 meses             │    │
│  │ (automático)  │            │         │                      │    │
│  ├───────────────┼────────────┼─────────┼──────────────────────┤    │
│  │ Backup manual │ Sob demanda│ —       │ Ilimitado (admin)    │    │
│  │ (via admin UI)│            │         │                      │    │
│  │               │            │         │                      │    │
│  │ Backup PDFs   │ Diário     │ 03:05   │ 90 dias              │    │
│  │ (relatórios)  │            │         │                      │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.2 Nomenclatura

```
Formato: backup_<TIPO>_<DATA>_<HORA>.dump

Exemplos:
  backup_DIARIO_20260513_030000.dump
  backup_SEMANAL_20260517_030000.dump
  backup_MENSAL_20260601_030000.dump
  backup_MANUAL_20260513_150000.dump
```

### 7.3 Automação (APScheduler dentro do Backend)

```python
# core/scheduler.py

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import subprocess
import os
from datetime import datetime
from pathlib import Path

scheduler = AsyncIOScheduler()

@scheduler.scheduled_job(CronTrigger(hour=3, minute=0))
async def backup_diario():
    """Backup diário automático."""
    agora = datetime.now()
    tipo = "SEMANAL" if agora.weekday() == 6 else \
           "MENSAL" if agora.day == 1 else "DIARIO"
    
    nome = f"backup_{tipo}_{agora:%Y%m%d_%H%M%S}.dump"
    caminho = Path("/backups") / nome
    
    # Executa pg_dump
    cmd = [
        "pg_dump",
        "-h", "db",
        "-U", os.environ["DB_USER"],
        "-d", os.environ["DB_NAME"],
        "-Fc",  # Formato customizado (comprimido)
        "-f", str(caminho),
        "-v"   # Verbose
    ]
    
    env = {"PGPASSWORD": os.environ["DB_PASSWORD"]}
    resultado = subprocess.run(cmd, capture_output=True, text=True, env=env)
    
    if resultado.returncode == 0:
        tamanho = caminho.stat().st_size
        # Registra no banco
        await registrar_backup(nome, str(caminho), tamanho, "auto", "sucesso")
        # Rotação
        await rotacionar_backups(tipo)
        logger.info(f"Backup {tipo} concluído: {nome} ({tamanho} bytes)")
    else:
        await registrar_backup(nome, str(caminho), 0, "auto", "falha",
                               resultado.stderr)
        logger.error(f"Backup {tipo} falhou: {resultado.stderr}")
```

### 7.4 Rotação

```python
async def rotacionar_backups(tipo: str):
    """
    Remove backups antigos conforme política de retenção.
    """
    retencoes = {
        "DIARIO": 30,
        "SEMANAL": 84,   # 12 semanas
        "MENSAL": 365,   # 12 meses
        "MANUAL": None,  # Nunca remove automático
    }
    
    dias = retencoes.get(tipo)
    if dias is None:
        return
    
    limite = datetime.now() - timedelta(days=dias)
    backups_dir = Path("/backups")
    
    for arquivo in backups_dir.glob(f"backup_{tipo}_*.dump"):
        if datetime.fromtimestamp(arquivo.stat().st_mtime) < limite:
            arquivo.unlink()
            logger.info(f"Backup removido por rotação: {arquivo.name}")
```

### 7.5 Restauração

```bash
#!/bin/bash
# scripts/restore.sh

BACKUP_FILE=$1
if [ -z "$BACKUP_FILE" ]; then
    echo "Uso: ./restore.sh <arquivo.dump>"
    echo "Backups disponíveis:"
    ls -lh /opt/sistema-ofs/backups/
    exit 1
fi

echo "⚠️  ATENÇÃO: Isso substituirá TODOS os dados atuais!"
echo "   Backup: $BACKUP_FILE"
read -p "   Digite 'CONFIRMAR' para continuar: " confirmacao

if [ "$confirmacao" != "CONFIRMAR" ]; then
    echo "Restauração cancelada."
    exit 0
fi

echo "🔄 Parando aplicação..."
docker compose stop backend

echo "🔄 Restaurando banco de dados..."
docker compose exec -T db pg_restore \
    -U ofs_user -d ofs_db --clean --if-exists \
    < /opt/sistema-ofs/backups/$BACKUP_FILE

echo "🔄 Reiniciando aplicação..."
docker compose start backend

echo "✅ Restauração concluída!"
docker compose ps
```

### 7.6 Verificação de Integridade

```bash
# Verificar se o backup está íntegro
docker compose exec backend pg_restore --list \
    /backups/backup_DIARIO_20260513_030000.dump \
    > /dev/null && echo "✅ Backup íntegro" || echo "❌ Backup corrompido"
```

---

## 8. Estratégia de Segurança

### 8.1 Política de Senhas

| Parâmetro | Valor |
|-----------|-------|
| Comprimento mínimo | 8 caracteres |
| Complexidade | 1 maiúscula + 1 minúscula + 1 número |
| Hash | bcrypt, cost factor 12 |
| Expiração | 90 dias (configurável) |
| Histórico | Não permitir reuso das últimas 5 senhas |
| Bloqueio | 5 tentativas falhas → 30 minutos |
| Primeiro acesso | Forçar alteração da senha padrão |

### 8.2 Controle de Sessão

| Configuração | Valor |
|-------------|-------|
| Access Token | JWT HS256, 15 minutos |
| Refresh Token | JWT HS256, 7 dias |
| Logout | Revoga refresh token (tabela tokens_revogados) |
| Sessão inativa | Access token expira automaticamente |
| Refresh | Cliente solicita novo access token com refresh token |
| Blacklist | Tokens revogados verificados a cada requisição |

### 8.3 JWT Payload

```json
{
  "sub": "uuid-do-usuario",
  "nome": "Carlos Oliveira",
  "login": "carlos.oliveira",
  "perfil": "supervisor",
  "empresa_id": 1,
  "contrato_id": 1,
  "iat": 1715600000,
  "exp": 1715600900,
  "jti": "uuid-unico-do-token"
}
```

### 8.4 RBAC — Controle de Perfis

```
┌────────────┬───────────────────────────────────────────────────────┐
│ Perfil     │ Permissões                                             │
├────────────┼───────────────────────────────────────────────────────┤
│ Observador │ • Criar OFS                                           │
│            │ • Ver/Editar seus OFCs (24h)                          │
│            │ • Gerar PDF individual (seus)                         │
├────────────┼───────────────────────────────────────────────────────┤
│ Supervisor │ • Tudo do Observador                                  │
│            │ • Ver/Editar OFCs do contrato (48h)                   │
│            │ • Métricas da Semana (contrato)                       │
│            │ • Relatórios (contrato)                               │
├────────────┼───────────────────────────────────────────────────────┤
│ Gestor     │ • Tudo do Supervisor (todos contratos)                │
│            │ • Cancelar OFS                                        │
│            │ • Editar sem limite de tempo                          │
│            │ • Gerenciar Metas                                     │
│            │ • Todos os relatórios                                 │
├────────────┼───────────────────────────────────────────────────────┤
│ Admin      │ • Acesso TOTAL                                        │
│            │ • CRUD Usuários, Empresas, Contratos, Locais          │
│            │ • Auditoria, Backup/Restore                           │
│            │ • Cancelar e restaurar OFCs                           │
└────────────┴───────────────────────────────────────────────────────┘
```

### 8.5 Proteções Implementadas

| Camada | Proteção |
|--------|----------|
| **Aplicação** | SQL Injection: ORM com bind parameters. XSS: React auto-escaping + CSP header. CSRF: token no header. Rate limiting: 100 req/min/IP. Input validation: Pydantic v2. |
| **Autenticação** | JWT com expiração curta. bcrypt cost 12. Lockout após 5 falhas. Refresh token rotation. Logout com revogação server-side. |
| **Container** | non-root user. read_only filesystem (onde possível). no-new-privileges. cap_drop: ALL. |
| **Rede** | Docker bridge network interna. Apenas nginx exposto (porta 80). PostgreSQL sem porta externa. |
| **Headers HTTP** | X-Frame-Options: DENY. X-Content-Type-Options: nosniff. X-XSS-Protection: 1; mode=block. Referrer-Policy: same-origin. |
| **Dados** | Senhas: bcrypt (nunca plain text). JWT secret: env var. DB password: env var. Logs: sem dados sensíveis. .env nunca commitado. |

### 8.6 Configuração de Rate Limiting (SlowAPI)

```python
# main.py
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])
app.state.limiter = limiter
app.add_exception_handler(429, _rate_limit_exceeded_handler)

# Endpoint de login: mais restritivo
@router.post("/api/auth/login")
@limiter.limit("10/minute")  # Máximo 10 tentativas/minuto
async def login(...):
    ...
```

---

## 9. Estratégia de Auditoria

### 9.1 Eventos Auditados

```
┌─────────────────────────────────────────────────────────────────────┐
│  AÇÃO                  │ ENTIDADE         │ SEVERIDADE │ DADOS      │
├────────────────────────┼──────────────────┼────────────┼────────────┤
│ LOGIN                  │ usuarios         │ INFO       │ ip         │
│ LOGIN_FALHA            │ usuarios         │ WARNING    │ login, ip  │
│ LOGOUT                 │ usuarios         │ INFO       │            │
│ CRIAR_OFC              │ ofc_registros    │ INFO       │ codigo,tipo│
│ EDITAR_OFC             │ ofc_registros    │ WARNING    │ campos alt.│
│ CANCELAR_OFC           │ ofc_registros    │ WARNING    │ motivo     │
│ RESTAURAR_OFC          │ ofc_registros    │ CRITICAL   │ admin      │
│ GERAR_PDF              │ relatorios       │ INFO       │ tipo, param│
│ DOWNLOAD_PDF           │ relatorios       │ INFO       │ arquivo    │
│ CRIAR_USUARIO          │ usuarios         │ WARNING    │ admin      │
│ ALTERAR_USUARIO        │ usuarios         │ WARNING    │ campos     │
│ DESATIVAR_USUARIO      │ usuarios         │ WARNING    │ admin      │
│ ALTERAR_META           │ metas_semanais   │ WARNING    │ old/new    │
│ BACKUP_MANUAL          │ backups          │ INFO       │ arquivo    │
│ RESTAURAR_BACKUP       │ backups          │ CRITICAL   │ admin      │
│ ACESSO_NEGADO          │ sistema          │ WARNING    │ recurso    │
│ EXPORTAR_RELATORIO     │ relatorios       │ INFO       │ tipo       │
└─────────────────────────────────────────────────────────────────────┘
```

### 9.2 Implementação (Middleware + Decorator)

```python
# core/audit.py

from functools import wraps
import json
from datetime import datetime, timezone

def auditar(acao: str, entidade: str):
    """Decorator para registrar auditoria automaticamente."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extrai parâmetros relevantes
            request = kwargs.get('request')
            usuario = kwargs.get('usuario') or kwargs.get('current_user')
            db = kwargs.get('db')
            
            # Executa a função original
            resultado = await func(*args, **kwargs)
            
            # Registra auditoria (async, non-blocking)
            if db and usuario:
                log = Auditoria(
                    usuario_id=usuario.id,
                    acao=acao,
                    entidade=entidade,
                    ip_origem=request.client.host if request else None,
                    dados_novos=_extrair_dados(resultado, kwargs),
                )
                db.add(log)
                # Commit feito pela transação principal
            
            return resultado
        return wrapper
    return decorator

# Uso:
@router.post("/api/OFS")
@auditar("CRIAR_OFC", "ofc_registros")
async def criar_ofc(...):
    ...
```

### 9.3 Estrutura da Tabela de Auditoria

```sql
CREATE TABLE auditoria (
    id              BIGSERIAL PRIMARY KEY,
    usuario_id      UUID REFERENCES usuarios(id),
    acao            VARCHAR(50) NOT NULL,
    entidade        VARCHAR(100) NOT NULL,
    entidade_id     VARCHAR(255),
    dados_anteriores JSONB,
    dados_novos      JSONB,
    ip_origem       VARCHAR(45),
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para consulta
CREATE INDEX idx_auditoria_ts ON auditoria(criado_em DESC);
CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id, criado_em DESC);
CREATE INDEX idx_auditoria_acao ON auditoria(acao);
```

### 9.4 Retenção e Consulta

| Parâmetro | Valor |
|-----------|-------|
| Retenção padrão | Indeterminada (até Admin purgar) |
| Purga configurável | Admin pode definir data limite |
| Consulta | `GET /api/auditoria?usuario_id=&acao=&entidade=&data_inicio=&data_fim=&page=` |
| Exportação | CSV (futuro) |
| Performance | Índice em `criado_em DESC` para queries por período |

---

## 10. Estratégia de Logs

### 10.1 Fontes de Log

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FONTES DE LOG                                 │
│                                                                      │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────────────┐   │
│  │ NGINX          │ │ BACKEND        │ │ POSTGRESQL             │   │
│  │                │ │                │ │                        │   │
│  │ /var/log/nginx │ │ /app/logs/     │ │ /var/log/postgresql/   │   │
│  │                │ │                │ │                        │   │
│  │ access.log     │ │ app.log        │ │ postgresql-*.log       │   │
│  │ (requisições)  │ │ (aplicação)    │ │ (banco)                │   │
│  │                │ │                │ │                        │   │
│  │ error.log      │ │ error.log      │ │                        │   │
│  │ (erros nginx)  │ │ (erros app)    │ │                        │   │
│  └────────────────┘ └────────────────┘ └────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ DOCKER                                                        │   │
│  │                                                                │   │
│  │ docker logs ofs-backend  → stdout/stderr dos containers       │   │
│  │ docker logs ofs-nginx                                       │   │
│  │ docker logs ofs-db                                          │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 10.2 Configuração de Logging (Backend)

```python
# core/logging_config.py

import logging
import json
import sys
from datetime import datetime, timezone

class JSONFormatter(logging.Formatter):
    """Formatter que emite logs em JSON estruturado."""
    
    SENSITIVE_FIELDS = {'password', 'senha', 'token', 'secret', 'authorization'}
    
    def format(self, record):
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
        }
        # Redact dados sensíveis
        if hasattr(record, 'extra_fields'):
            for key, value in record.extra_fields.items():
                if key.lower() in self.SENSITIVE_FIELDS:
                    log_entry[key] = "***REDACTED***"
                else:
                    log_entry[key] = value
        if record.exc_info and record.exc_info[1]:
            log_entry["exception"] = str(record.exc_info[1])
        return json.dumps(log_entry, ensure_ascii=False)

def setup_logging(level: str = "INFO"):
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper()))
    root.handlers.clear()
    root.addHandler(handler)
    
    # Reduzir verbosidade de bibliotecas
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("matplotlib").setLevel(logging.WARNING)
    logging.getLogger("weasyprint").setLevel(logging.WARNING)
    logging.getLogger("apscheduler").setLevel(logging.WARNING)
```

### 10.3 Rotação de Logs

```bash
#!/bin/bash
# scripts/rotate-logs.sh

LOG_DIR="/opt/sistema-ofs/logs"
RETENTION_DAYS=30

# Comprime logs antigos
find "$LOG_DIR" -name "*.log" -mtime +1 -exec gzip {} \;

# Remove logs comprimidos após retenção
find "$LOG_DIR" -name "*.log.gz" -mtime +$RETENTION_DAYS -delete

echo "Rotação de logs concluída: $(date)"
```

### 10.4 Política de Retenção

| Fonte | Retenção |
|-------|----------|
| app.log | 30 dias |
| error.log | 90 dias |
| nginx access.log | 30 dias |
| nginx error.log | 90 dias |
| postgresql logs | 30 dias |
| auditoria (banco) | Indeterminada |
| docker logs | Gerenciado pelo Docker (max-size: 10m, max-file: 3) |

---

## 11. Estratégia de PDF

### 11.1 Stack e Responsabilidades

```
┌───────────────────────────────────────────────────────────────┐
│                   PIPELINE DE GERAÇÃO DE PDF                   │
│                                                                │
│  1. COLETA DE DADOS                                            │
│     └─▶ SQLAlchemy queries otimizadas                          │
│                                                                │
│  2. GERAÇÃO DE GRÁFICOS                                        │
│     └─▶ matplotlib 3.8+ (backend 'Agg')                        │
│         ├─▶ PNG em BytesIO                                     │
│         ├─▶ Conversão para base64                               │
│         └─▶ Inserção no template: <img src="data:image/png;... │
│                                                                │
│  3. RENDERIZAÇÃO HTML                                          │
│     └─▶ Jinja2 3.x                                             │
│         ├─▶ Template _base.html (header, footer, @page CSS)    │
│         ├─▶ Templates específicos (individual, semanal, etc.)   │
│         └─▶ Fontes Inter locais (@font-face com path absoluto) │
│                                                                │
│  4. CONVERSÃO HTML → PDF                                       │
│     └─▶ WeasyPrint 61+                                         │
│         ├─▶ Zero dependência de browser                        │
│         ├─▶ Suporte a CSS Paged Media                          │
│         ├─▶ Headers e footers fixos por página                 │
│         └─▶ Margens, quebras de página, numeração              │
│                                                                │
│  5. ARMAZENAMENTO                                              │
│     └─▶ /app/reports/<nome_arquivo>.pdf                        │
│         ├─▶ Registro na tabela relatorios_gerados              │
│         └─▶ Auditoria GERAR_PDF                                │
│                                                                │
│  6. DOWNLOAD                                                   │
│     └─▶ GET /api/relatorios/{id}/download                      │
│         ├─▶ StreamingResponse (FileResponse)                   │
│         ├─▶ Content-Type: application/pdf                      │
│         └─▶ Content-Disposition: attachment                    │
└───────────────────────────────────────────────────────────────┘
```

### 11.2 Requisitos Técnicos

| Requisito | Implementação |
|-----------|---------------|
| Sem internet | WeasyPrint + matplotlib 100% offline. Fontes locais. Logo local. |
| A4 retrato | `@page { size: A4; margin: 20mm; }` |
| A4 paisagem | `@page landscape { size: A4 landscape; }` |
| Cabeçalho fixo | `position: running(pageHeader)` + `@top-center { content: element(pageHeader); }` |
| Rodapé fixo | `position: running(pageFooter)` + `@bottom-center { content: element(pageFooter); }` |
| Logo | `<img src="data:image/png;base64,...">` (embed, sem path) |
| Fontes | Inter .woff2 carregadas via @font-face com path local |
| Nº de página | CSS counter: `counter(page)` |
| Performance | Async. Timeout 60s. PNGs em memória (sem disco). |

### 11.3 Retenção de PDFs

| Tipo | Retenção |
|------|----------|
| PDFs no disco | 90 dias (remoção automática por scheduler) |
| Registro no banco (relatorios_gerados) | Indeterminado (metadados) |

---

## 12. Estratégia de Gráficos

### 12.1 Frontend vs Backend

```
┌─────────────────────────┬──────────────────────────────────┐
│ FRONTEND (Recharts)     │ BACKEND (matplotlib)             │
├─────────────────────────┼──────────────────────────────────┤
│ Uso: Dashboards         │ Uso: PDFs                        │
│ Interativo              │ Estático (PNG)                   │
│ SVG (vetorial, leve)    │ PNG 150 DPI (alta qualidade)     │
│ Tempo real              │ Gerado sob demanda               │
│ Responsivo              │ Tamanho fixo (cm)                │
│ Biblioteca: Recharts    │ Biblioteca: matplotlib           │
│ Peso: ~50KB             │ Peso: ~15MB (já instalado)       │
└─────────────────────────┴──────────────────────────────────┘
```

### 12.2 Configuração matplotlib para PDF

```python
import matplotlib
matplotlib.use('Agg')  # Backend não-interativo (essencial para servidor)

import matplotlib.pyplot as plt

# Configuração global
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.size': 10,
    'figure.dpi': 150,          # Alta resolução para PDF
    'savefig.dpi': 150,
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.1,
    'figure.facecolor': 'white',
})

# Cache de figuras para performance
from functools import lru_cache
import hashlib

@lru_cache(maxsize=32)
def gerar_grafico_cacheado(tipo: str, dados_hash: str, *args):
    """Cache de gráficos para evitar re-renderização."""
    ...
```

### 12.3 Tabela de Gráficos por Contexto

| Gráfico | Frontend (Recharts) | Backend/PDF (matplotlib) | Tipo |
|---------|:---:|:---:|------|
| Programado x Realizado | ✅ | ✅ | Barras |
| Positivo x Negativo | ✅ | ✅ | Rosca |
| OFS por Empresa | ✅ | ✅ | Barras horiz. |
| OFS por Usuário | ✅ | ✅ | Barras horiz. |
| OFS por Turno | ✅ | ✅ | Pizza |
| Top Comportamentos | ✅ | ✅ | Barras horiz. |
| Evolução Semanal | ✅ | ✅ | Linha |
| Evolução Mensal | ✅ | ✅ | Linha |
| Desvios por Local | ✅ | ✅ | Barras horiz. |
| Desvios por Turno | ✅ | ✅ | Pizza |

---

## 13. Estratégia de Escalabilidade Futura

### 13.1 Fases de Escala

```
┌─────────────────────────────────────────────────────────────────────┐
│  FASE 1 (MVP)           FASE 2 (Crescimento)    FASE 3 (Cloud)      │
│  ────────────           ───────────────────     ──────────────       │
│  10-50 usuários         50-200 usuários         200-500+ usuários    │
│                                                                      │
│  1 servidor             1-2 servidores         Nuvem (AWS/Azure/GCP) │
│  3 containers           4-5 containers         Orquestração (K8s)    │
│  PostgreSQL local        PostgreSQL + réplica   RDS / Cloud SQL      │
│  Cache em memória        Redis                  Redis / ElastiCache  │
│  PDF síncrono            PDF assíncrono (fila)  Celery + S3          │
│  Backup local            Backup local + NAS     S3 / Blob Storage    │
│  Deploy manual           CI/CD básico           CI/CD completo       │
│  HTTP                    HTTPS (CA interna)     HTTPS (ACM)          │
└─────────────────────────────────────────────────────────────────────┘
```

### 13.2 O Que Já Nasce Desacoplado

| Componente | Desacoplamento |
|-----------|----------------|
| Frontend | Servido como estáticos. Pode ir para CDN/S3 no futuro. |
| Backend | Stateless (sem sessão). Pode ter múltiplas instâncias atrás de load balancer. |
| Banco | URL de conexão via env var. Trocar para RDS é mudar uma string. |
| PDFs | Caminho via env var. Trocar para S3 é implementar um storage backend. |
| Backups | Caminho via env var. Trocar para S3 é script de sync. |
| Configuração | 100% env vars. Secrets Manager no futuro. |
| Logs | stdout. CloudWatch / Azure Monitor no futuro. |

### 13.3 Pontos de Atenção para Escala

```
1. ofc_registros é a tabela que mais cresce (~50k registros/ano)
   → Particionamento por mês/ano (Fase 2)
   → Índices parciais (WHERE is_deleted = FALSE)
   
2. Métricas semanais consultam muitos dados
   → Views materializadas (Fase 2)
   → Cache Redis para resultados de métricas
   
3. Geração de PDF é CPU-intensiva
   → Processamento assíncrono (Fila Redis + Worker)
   → Limitar PDFs simultâneos (semáforo)
   
4. Backups diários crescem em disco
   → Compressão (pg_dump -Fc já comprime)
   → Offload para NAS ou S3 após 30 dias
```

---

## 14. Estratégia de Migração para Nuvem

### 14.1 Mapeamento de Serviços

| Componente MVP | AWS | Azure | Google Cloud |
|---------------|-----|-------|-------------|
| **Frontend (estático)** | S3 + CloudFront | Blob Storage + CDN | Cloud Storage + CDN |
| **Backend (container)** | ECS Fargate / EKS | ACI / AKS | Cloud Run / GKE |
| **PostgreSQL** | RDS PostgreSQL | Azure PostgreSQL | Cloud SQL |
| **PDFs gerados** | S3 | Blob Storage | Cloud Storage |
| **Backups** | S3 (Lifecycle policy) | Blob Storage | Cloud Storage |
| **Cache** | ElastiCache (Redis) | Azure Cache for Redis | Memorystore |
| **Filas** | SQS | Service Bus | Pub/Sub |
| **Secrets** | Secrets Manager | Key Vault | Secret Manager |
| **DNS** | Route 53 | Azure DNS | Cloud DNS |
| **SSL** | ACM | Azure Certificate | Managed Certificate |
| **Logs** | CloudWatch | Azure Monitor | Cloud Logging |
| **CI/CD** | CodePipeline / GH Actions | Azure DevOps / GH Actions | Cloud Build / GH Actions |

### 14.2 Variáveis de Ambiente para Cloud

```bash
# .env.cloud (exemplo AWS)
AMBIENTE=producao
DB_HOST=ofs-db.xxxxxx.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=ofs_db
DB_USER=ofs_user
DB_PASSWORD=<via Secrets Manager>
DB_SSL=true

JWT_SECRET=<via Secrets Manager>

REPORTS_STORAGE=s3
S3_BUCKET=ofs-reports
S3_REGION=us-east-1

BACKUP_STORAGE=s3
BACKUP_S3_BUCKET=ofs-backups

REDIS_URL=redis://ofs-cache.xxxxxx.0001.use1.cache.amazonaws.com:6379

CORS_ORIGINS=https://ofs.securitydynamics.com.br

LOG_LEVEL=INFO
SENTRY_DSN=<via Secrets Manager>
```

### 14.3 Passos para Migração

```
1. Exportar banco: pg_dump → .dump
2. Criar RDS PostgreSQL e importar .dump
3. Criar S3 bucket para PDFs e backups
4. Ajustar .env.cloud com novos endpoints
5. Build e push da imagem Docker para ECR
6. Criar ECS Service (Fargate) com a imagem
7. Configurar ALB (Application Load Balancer)
8. Apontar DNS para ALB
9. Configurar CloudFront para o frontend
10. Testar, validar, cortar tráfego
```

### 14.4 Infraestrutura como Código (Futuro — Terraform)

```
infra/
├── terraform/
│   ├── main.tf              # Provider + backend
│   ├── vpc.tf               # Rede
│   ├── rds.tf               # PostgreSQL
│   ├── ecs.tf               # Backend (Fargate)
│   ├── s3.tf                # Frontend + PDFs + Backups
│   ├── cloudfront.tf        # CDN
│   ├── route53.tf           # DNS
│   ├── secrets.tf           # Secrets Manager
│   └── variables.tf         # Variáveis
└── kubernetes/              # Alternativa K8s
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── configmap.yaml
```

---

## 15. Estratégia de Atualização

### 15.1 Fluxo de Deploy/Atualização

```
┌─────────────────────────────────────────────────────────────────────┐
│  FLUXO DE ATUALIZAÇÃO DO SISTEMA                                     │
│                                                                      │
│  1. DESENVOLVIMENTO                                                  │
│     git pull / git clone (repositório interno)                       │
│     ├─▶ Alterações no código                                        │
│     ├─▶ Testes locais                                                │
│     └─▶ git commit + git push                                       │
│                                                                      │
│  2. BUILD                                                            │
│     No servidor de homologação (ou máquina com internet):            │
│     ├─▶ npm run build (frontend)                                    │
│     ├─▶ docker compose build (backend)                              │
│     └─▶ Testes de integração                                        │
│                                                                      │
│  3. DEPLOY (produção)                                                │
│     Opção A — Servidor com internet:                                 │
│       git pull                                                       │
│       docker compose build                                           │
│       docker compose up -d                                           │
│                                                                      │
│     Opção B — Servidor OFFLINE:                                      │
│       # Na máquina de build:                                         │
│       docker save ofs-backend:latest -o ofs-backend.tar             │
│       npm run build && tar -czf frontend-dist.tar.gz dist/          │
│                                                                      │
│       # Copia via pendrive/rede para o servidor                      │
│       scp ofs-backend.tar frontend-dist.tar.gz user@servidor:/tmp/  │
│                                                                      │
│       # No servidor:                                                 │
│       docker load -i /tmp/ofs-backend.tar                           │
│       tar -xzf /tmp/frontend-dist.tar.gz -C /opt/sistema-ofs/frontend│
│       docker compose up -d                                           │
│                                                                      │
│  4. VERIFICAÇÃO                                                      │
│     ├─▶ docker compose ps (todos UP)                                │
│     ├─▶ curl http://localhost:8000/health                           │
│     ├─▶ Acessar http://192.168.1.100 no navegador                   │
│     └─▶ Testar login, criar OFS, gerar PDF                          │
└─────────────────────────────────────────────────────────────────────┘
```

### 15.2 Script de Deploy

```bash
#!/bin/bash
# scripts/deploy.sh

set -e  # Para em caso de erro

echo "🚀 Iniciando deploy do Sistema OFS/OFS..."
echo "Data: $(date)"

# 1. Backup pré-deploy
echo "📦 Criando backup pré-deploy..."
docker compose exec backend python -m app.cli backup --type manual

# 2. Build
echo "🔨 Build das imagens..."
docker compose build backend

# 3. Build frontend (se necessário)
if [ -f "frontend/package.json" ]; then
    echo "🔨 Build do frontend..."
    cd frontend && npm run build && cd ..
fi

# 4. Deploy
echo "🚀 Subindo containers..."
docker compose up -d

# 5. Migrations
echo "🗄️ Executando migrações..."
docker compose exec backend alembic upgrade head

# 6. Health check
echo "🏥 Verificando saúde do sistema..."
sleep 5
HEALTHY=true

for service in nginx backend db; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' ofs-$service 2>/dev/null)
    if [ "$STATUS" != "healthy" ]; then
        echo "⚠️  ofs-$service: $STATUS"
        HEALTHY=false
    else
        echo "✅ ofs-$service: $STATUS"
    fi
done

if [ "$HEALTHY" = true ]; then
    echo "✅ Deploy concluído com sucesso!"
    docker compose ps
else
    echo "❌ Problemas detectados. Verificando logs..."
    docker compose logs --tail=20
    exit 1
fi
```

### 15.3 Migrations (Alembic)

```bash
# Criar nova migração
docker compose exec backend alembic revision --autogenerate -m "descricao"

# Aplicar migrações
docker compose exec backend alembic upgrade head

# Rollback
docker compose exec backend alembic downgrade -1

# Ver histórico
docker compose exec backend alembic history
```

---

## 16. Estratégia de Monitoramento

### 16.1 Checks de Saúde (Health Endpoints)

```python
# main.py

@app.get("/health")
async def health_check(db: AsyncSession = Depends(get_db)):
    """Health check completo."""
    checks = {}
    
    # 1. Banco de dados
    try:
        await db.execute(text("SELECT 1"))
        checks["database"] = "ok"
    except Exception as e:
        checks["database"] = f"error: {str(e)}"
    
    # 2. Sistema de arquivos (PDFs)
    reports_dir = Path(settings.REPORTS_DIR)
    checks["reports_dir"] = "ok" if reports_dir.exists() and os.access(reports_dir, os.W_OK) else "error"
    
    # 3. Backups
    backups_dir = Path(settings.BACKUP_DIR)
    checks["backups_dir"] = "ok" if backups_dir.exists() else "error"
    
    # Status geral
    all_ok = all(v == "ok" for v in checks.values())
    status_code = 200 if all_ok else 503
    
    return JSONResponse(
        content={
            "status": "healthy" if all_ok else "unhealthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": checks,
        },
        status_code=status_code,
    )
```

### 16.2 Comandos de Verificação Manual

```bash
# scripts/health-check.sh

#!/bin/bash
echo "═══════════════════════════════════"
echo "  VERIFICAÇÃO DE SAÚDE — SISTEMA OFS/OFS"
echo "  $(date)"
echo "═══════════════════════════════════"

# 1. Containers
echo ""
echo "📦 CONTAINERS:"
docker compose ps

# 2. Health API
echo ""
echo "🏥 HEALTH API:"
curl -s http://localhost:8000/health | python -m json.tool

# 3. Espaço em disco
echo ""
echo "💾 DISCO:"
df -h /opt/sistema-ofs/

# 4. Último backup
echo ""
echo "📦 ÚLTIMO BACKUP:"
ls -lht /opt/sistema-ofs/backups/ | head -5

# 5. Últimos logs de erro
echo ""
echo "📋 ÚLTIMOS ERROS (backend):"
docker compose logs --tail=10 backend 2>/dev/null | grep -i error || echo "  Nenhum erro recente"

# 6. Conexões do banco
echo ""
echo "🗄️ CONEXÕES DO BANCO:"
docker compose exec db psql -U ofs_user -d ofs_db -c \
    "SELECT count(*) as conexoes_ativas FROM pg_stat_activity WHERE state = 'active';"

echo ""
echo "✅ Verificação concluída."
```

### 16.3 Monitoramento Básico com Docker

```yaml
# docker-compose.yml (adicional)
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
```

---

## 17. Requisitos Mínimos do Servidor

### 17.1 Hardware

| Componente | Mínimo (MVP 10-50 usuários) | Recomendado (50-200 usuários) | Cloud (200+) |
|-----------|:---:|:---:|:---:|
| **CPU** | 2 vCPUs | 4 vCPUs | 8+ vCPUs (auto-scale) |
| **RAM** | 4 GB | 8 GB | 16 GB+ |
| **Disco** | 50 GB SSD | 100 GB SSD | EBS/Managed Disk (auto-expand) |
| **Rede** | 100 Mbps | 1 Gbps | Load Balancer |

### 17.2 Software

| Software | Versão | Observação |
|----------|--------|-----------|
| Sistema Operacional | Ubuntu Server 22.04 LTS | Recomendado. Windows Server 2019+ alternativo |
| Docker Engine | 24+ | Inclui Docker Compose v2 |
| Docker Compose | v2.20+ | Plugin (não standalone) |
| Git | 2.40+ | Apenas se fizer git pull no servidor |
| Navegadores suportados | Chrome 90+, Edge 90+, Firefox 90+ | Nos clientes |

### 17.3 Dimensionamento de Disco

```
┌──────────────────────────────────────────────────────────────┐
│  USO DE DISCO ESTIMADO (50 usuários, 1 ano)                  │
│                                                               │
│  PostgreSQL (dados + índices + WAL):      ~2 GB               │
│  Backups (30 × ~50MB comprimidos):         ~2 GB              │
│  PDFs gerados (~500 × ~250KB):            ~125 MB             │
│  Logs (30 dias):                           ~500 MB            │
│  Sistema + Docker images:                  ~2 GB              │
│  ─────────────────────────────────────────                   │
│  TOTAL ESTIMADO:                           ~7 GB              │
│  MARGEM DE SEGURANÇA (2x):                ~14 GB              │
│  ─────────────────────────────────────────                   │
│  RECOMENDAÇÃO: 50 GB SSD (espaço para 3+ anos)               │
└──────────────────────────────────────────────────────────────┘
```

---

## 18. Checklist de Implantação do Ambiente

### 18.1 Preparação do Servidor (Linux)

- [ ] Instalar Ubuntu Server 22.04 LTS
- [ ] Configurar IP fixo na rede local (ex: 192.168.1.100)
- [ ] Criar usuário de serviço: `sudo useradd -m -s /bin/bash ofs`
- [ ] Instalar Docker Engine 24+
  ```bash
  curl -fsSL https://get.docker.com | sudo bash
  sudo usermod -aG docker ofs
  ```
- [ ] Instalar Docker Compose Plugin
  ```bash
  sudo apt install docker-compose-v2
  ```
- [ ] Verificar: `docker --version && docker compose version`
- [ ] Configurar firewall (apenas portas 80, 443, 22)
  ```bash
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw enable
  ```
- [ ] Criar diretório do projeto: `sudo mkdir -p /opt/sistema-ofs`
- [ ] Ajustar permissões: `sudo chown -R ofs:ofs /opt/sistema-ofs`

### 18.2 Transferência do Código (Servidor OFFLINE)

- [ ] Em máquina com internet, buildar as imagens:
  ```bash
  docker compose build
  docker save ofs-backend:latest -o ofs-backend.tar
  ```
- [ ] Buildar frontend:
  ```bash
  cd frontend && npm run build
  tar -czf frontend-dist.tar.gz dist/
  ```
- [ ] Copiar para o servidor via pendrive/rede:
  ```
  ofs-backend.tar
  frontend-dist.tar.gz
  docker-compose.yml
  .env (preenchido)
  pasta nginx/
  pasta db/
  ```
- [ ] No servidor, extrair:
  ```bash
  cd /opt/sistema-ofs
  docker load -i /tmp/ofs-backend.tar
  tar -xzf /tmp/frontend-dist.tar.gz -C frontend/
  ```

### 18.3 Primeiro Deploy

- [ ] Criar `.env` com senhas fortes
- [ ] Criar diretórios de volumes:
  ```bash
  mkdir -p reports backups logs/{nginx,app}
  ```
- [ ] Subir containers:
  ```bash
  docker compose up -d
  ```
- [ ] Verificar status:
  ```bash
  docker compose ps
  ```
- [ ] Executar migrations:
  ```bash
  docker compose exec backend alembic upgrade head
  ```
- [ ] Criar admin (se não estiver no seed):
  ```bash
  docker compose exec backend python -m app.cli create-admin
  ```
- [ ] Verificar health check:
  ```bash
  curl http://localhost:8000/health
  ```
- [ ] Testar no navegador: `http://192.168.1.100`

### 18.4 Pós-Deploy — Verificações

- [ ] Login com admin / senha padrão
- [ ] Alterar senha do admin (primeiro acesso)
- [ ] Cadastrar empresa (se necessário além das 15)
- [ ] Cadastrar contrato
- [ ] Cadastrar locais
- [ ] Cadastrar usuários (Observador, Supervisor, Gestor)
- [ ] Definir metas da semana atual
- [ ] Criar um OFS de teste
- [ ] Consultar OFS criado
- [ ] Verificar Métricas da Semana
- [ ] Gerar PDF individual
- [ ] Gerar PDF semanal
- [ ] Verificar download dos PDFs
- [ ] Verificar backup manual (Admin → Backup)
- [ ] Verificar logs de auditoria
- [ ] Testar em celular/tablet (rede interna)

### 18.5 Configuração de Backup Automático

- [ ] Verificar se APScheduler está ativo:
  ```bash
  docker compose logs backend | grep "scheduler"
  ```
- [ ] Aguardar primeiro backup automático (03:00 AM)
- [ ] Verificar arquivo gerado:
  ```bash
  ls -lh /opt/sistema-ofs/backups/
  ```
- [ ] Testar restore em ambiente isolado (não em produção)

### 18.6 Manutenção Programada

- [ ] **Diário**: Verificar status dos containers (`docker compose ps`)
- [ ] **Semanal**: Verificar espaço em disco (`df -h`)
- [ ] **Mensal**: Testar restore de backup em ambiente isolado
- [ ] **Trimestral**: Atualizar dependências (security patches)
- [ ] **Semestral**: Revisar logs de auditoria, purgar se necessário

---

**Documento gerado em 13/05/2026.**
