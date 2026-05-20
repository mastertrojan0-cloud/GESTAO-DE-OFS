/opt/sistema-ofs/
│
├── docker-compose.yml              # Orquestracao (3 servicos)
├── .env                             # Variaveis de ambiente (NAO COMMITAR)
├── .env.example                     # Template
│
├── backend/
│   ├── Dockerfile                   # Multi-stage, non-root
│   ├── requirements.txt             # Dependencias Python
│   ├── app/                         # Codigo FastAPI
│   │   ├── main.py
│   │   ├── core/                    # config, security, scheduler, permissions
│   │   ├── api/                     # Rotas (auth, OFS, audit, backup, health)
│   │   ├── models/                  # SQLAlchemy ORM
│   │   ├── schemas/                 # Pydantic v2
│   │   ├── services/                # Logica de negocio
│   │   └── db/                      # Engine, session
│   ├── migrations/                  # Alembic + scripts init DB
│   ├── static/                      # Fontes (Inter .woff2), logos
│   └── templates/                   # Jinja2 (PDFs)
│
├── frontend/
│   ├── src/                         # React + Vite + TypeScript
│   ├── public/
│   └── dist/                        # Build de producao (gerado)
│
├── nginx/
│   └── nginx.conf                   # Configuracao unica
│
├── backups/                         # Volume: arquivos .dump
│   ├── daily/
│   ├── weekly/
│   └── monthly/
│
├── reports/                         # Volume: PDFs gerados
│
└── scripts/                         # Manutencao
    ├── backup.sh                    # Backup manual / cron
    ├── restore.sh                   # Restauracao interativa
    └── health-check.sh              # Verificacao do ambiente
