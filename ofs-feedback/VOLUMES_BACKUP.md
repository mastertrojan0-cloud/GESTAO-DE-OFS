# O que NAO precisa de Volume / Backup
# Sistema OFS/OFS - Security Dynamics

## Volumes (3, apenas os essenciais)

| Volume               | Tipo         | Por que                                    |
|----------------------|-------------|---------------------------------------------|
| pgdata               | Named       | Dados do banco. UNICO estado real           |
| ./backups            | Bind mount  | Arquivos .dump gerados pelo pg_dump         |
| ./reports            | Bind mount  | PDFs gerados. Opcional via API download      |

## O que NAO precisa de volume persistente

| Componente                 | Motivo                                               |
|----------------------------|------------------------------------------------------|
| nginx/nginx.conf           | Read-only, versionado no codigo fonte                |
| frontend/dist/             | Read-only, build gerado a partir do codigo fonte     |
| backend/static/            | Read-only, assets versionados (fontes, logos)        |
| backend/templates/         | Read-only, templates Jinja2 versionados              |
| backend/migrations/        | Read-only, scripts Alembic versionados               |
| Logs da aplicacao          | stdout/stderr do container → `docker compose logs`   |
| Dependencias pip           | Dentro da imagem Docker (camada imutavel)            |
| Cache de dependencias npm  | Dentro do build do frontend (descartavel)            |
| .env                       | Arquivo unico no host, fora de volumes               |

## O que NAO precisa de backup

| Dado            | Motivo                                                   |
|-----------------|----------------------------------------------------------|
| PDFs gerados    | Gerados sob demanda. Se perder, regerar via API           |
| Logs            | Descartaveis. stdout/stderr capturados pelo Docker        |
| Token cache     | JWT stateless. Blacklist em RAM com expiracao automatica |
| Sessoes         | Stateless (JWT). Sem sessao no servidor                  |
| Metrics cache   | TTLCache em memoria. Recalculado sob demanda             |
| Imagens Docker  | Reconstruidas do codigo fonte + Dockerfile               |
| node_modules    | Reinstalaveis via npm ci (offline com package-lock)      |
| .pyc / __pycache__ | Gerados automaticamente pelo Python                   |

## Volume Strategy (Resumo)

```
VOLUMES COM BACKUP:               VOLUMES SEM BACKUP (CODIGO):
┌──────────────────────────┐      ┌──────────────────────────┐
│ pgdata  → backup diario  │      │ nginx.conf               │
│ ./backups → copiar p/ NAS│      │ frontend/dist/           │
│                          │      │ backend/static/          │
│ VOLUMES COM RETENCAO:    │      │ backend/templates/       │
│ ./reports → 90d (opc.)   │      │ backend/migrations/      │
└──────────────────────────┘      └──────────────────────────┘
```
