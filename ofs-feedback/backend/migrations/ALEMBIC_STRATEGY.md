# ESTRATEGIA DE MIGRATIONS — ALEMBIC + PostgreSQL 16

## Stack

- **ORM:** SQLAlchemy 2.0 (async)
- **Migration tool:** Alembic
- **Database:** PostgreSQL 16
- **Ambiente:** Offline (sem internet, dependencias ja instaladas localmente)

## Estrutura de Arquivos

```
backend/
├── alembic.ini                  ← config Alembic
├── alembic/
│   ├── env.py                   ← engine async, carrega metadata
│   ├── script.py.mako           ← template de migration
│   └── versions/
│       ├── 001_initial_schema.py
│       └── 002_seed_data.py
├── migrations/
│   ├── 001_initial_schema.sql   ← SQL puro (referencia)
│   ├── 002_seed_data.sql        ← SQL puro (referencia)
│   └── ALEMBIC_STRATEGY.md      ← este documento
└── app/
    ├── db/
    │   ├── base.py              ← Base = DeclarativeBase
    │   └── session.py           ← AsyncSession
    └── models/
        ├── empresa.py
        ├── usuario.py
        ├── OFS.py
        ├── meta.py
        ├── auditoria.py
        └── auth_models.py
```

## 1. Inicializacao do Alembic

```bash
# Dentro de backend/
cd backend

# Instalar Alembic (ja deve estar no requirements.txt)
pip install alembic

# Inicializar estrutura
alembic init alembic
```

## 2. Configurar alembic.ini

```ini
# Substituir a linha sqlalchemy.url
sqlalchemy.url = postgresql+asyncpg://ofs_app_role:CHANGE_ME_APP_PASSWORD@localhost:5432/ofs_db
```

## 3. Configurar alembic/env.py

```python
import asyncio
from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config
from alembic import context

# Import Base + todos os modelos
from app.db.base import Base
from app.models import *  # importa empresa, usuario, OFS, meta, auditoria, auth_models

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

def run_migrations_offline() -> None:
    """Migration em modo offline (gera SQL sem conexao)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()

def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

## 4. Migration 001 — Schema Inicial (todas as tabelas)

### Gerar automaticamente a partir dos modelos:

```bash
# Ambiente offline: gerar SQL primeiro, depois aplicar
alembic revision --autogenerate -m "initial_schema"

# Revisar o arquivo gerado em alembic/versions/<hash>_initial_schema.py
# Aplicar:
alembic upgrade head

# Para gerar apenas o SQL (sem executar):
alembic upgrade head --sql > migration_001_output.sql
```

### Estrutura do upgrade (arquivo Python):

```python
"""initial_schema

Revision ID: 001
Revises: None  (migration inicial)
Create Date: 2026-05-13
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # Extensoes
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto"')
    op.execute('CREATE EXTENSION IF NOT EXISTS "unaccent"')
    op.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm"')

    # Tabelas — mesma ordem do 001_initial_schema.sql
    op.create_table('empresas', ...)
    op.create_table('contratos', ...)
    op.create_table('usuarios', ...)
    op.create_table('system_params', ...)
    op.create_table('metas', ...)
    op.create_table('ofcs', ...)
    op.create_table('password_history', ...)
    op.create_table('refresh_tokens', ...)
    op.create_table('revoked_tokens', ...)
    op.create_table('login_attempts', ...)
    op.create_table('audit_logs', ...)
    op.create_table('ofc_edit_log', ...)
    op.create_table('backups', ...)
    op.create_table('app_state', ...)

    # Indices + Triggers ...

def downgrade() -> None:
    # Drop em ordem reversa (FKs primeiro)
    op.drop_table('app_state')
    op.drop_table('backups')
    op.drop_table('ofc_edit_log')
    op.drop_table('audit_logs')
    op.drop_table('login_attempts')
    op.drop_table('revoked_tokens')
    op.drop_table('refresh_tokens')
    op.drop_table('password_history')
    op.drop_table('ofcs')
    op.drop_table('metas')
    op.drop_table('system_params')
    op.drop_table('usuarios')
    op.drop_table('contratos')
    op.drop_table('empresas')
```

## 5. Migration 002 — Seeds (empresas, admin, parametros, dados de teste)

```python
"""seed_data

Revision ID: 002
Revises: 001
Create Date: 2026-05-13
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '002'
down_revision: Union[str, None] = '001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # Executar SQL puro do arquivo 002_seed_data.sql
    # Opcao A: inline (copiar INSERTs para ca)
    # Opcao B: op.execute(open('migrations/002_seed_data.sql').read())
    pass

def downgrade() -> None:
    # Remove todos os dados inseridos
    op.execute("DELETE FROM metas WHERE id = 'g1000000-0000-0000-0000-000000000001'")
    op.execute("DELETE FROM system_params WHERE id LIKE 's1000000%'")
    op.execute("DELETE FROM app_state WHERE key IN ('maintenance_mode','system_version')")
    op.execute("DELETE FROM ofc_edit_log")
    op.execute("DELETE FROM ofcs WHERE id LIKE 'e0000000%'")
    op.execute("DELETE FROM password_history WHERE user_id LIKE 'd1000000%'")
    op.execute("DELETE FROM usuarios WHERE id LIKE 'd1000000%'")
    op.execute("DELETE FROM contratos WHERE id = 'f1000000-0000-0000-0000-000000000001'")
    op.execute("DELETE FROM empresas WHERE id LIKE 'a1000000%'")
```

## 6. Comandos Operacionais

### Ambiente Offline (recomendado para este cenario)

```bash
# 1. Gerar SQL da migration 001 (sem executar)
cd backend
alembic upgrade head --sql 2>&1 | Select-String -NotMatch "^INFO" > migrations\001_output.sql

# 2. Revisar o SQL gerado
notepad migrations\001_output.sql

# 3. Conectar ao banco e executar manualmente
psql -h localhost -U ofs_admin_role -d ofs_db -f migrations\001_initial_schema.sql

# 4. Verificar que a migration foi aplicada
psql -h localhost -U ofs_admin_role -d ofs_db -c "SELECT * FROM verify_migration_001();"

# 5. Aplicar seeds
psql -h localhost -U ofs_admin_role -d ofs_db -f migrations\002_seed_data.sql

# 6. Marcar migrations como aplicadas no Alembic
alembic stamp head
```

### Ambiente Online (com conexao ao banco)

```bash
# Listar historico
alembic history

# Aplicar todas as migrations pendentes
alembic upgrade head

# Aplicar uma migration especifica
alembic upgrade 001

# Downgrade (voltar uma migration)
alembic downgrade -1

# Downgrade para o estado inicial (vazio)
alembic downgrade base

# Gerar nova migration automatica apos alterar modelos
alembic revision --autogenerate -m "descricao_da_alteracao"

# Verificar se ha alteracoes pendentes nos modelos
alembic check

# Mostrar SQL da migration sem executar
alembic upgrade head --sql

# Ver status atual
alembic current
```

### Verificacao e Diagnostico

```bash
# Tabelas existentes
psql -d ofs_db -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY 1;"

# Tabela de controle do Alembic
psql -d ofs_db -c "SELECT * FROM alembic_version;"

# Contagem de registros apos seed
psql -d ofs_db -c "
SELECT 'empresas' as tabela, COUNT(*) FROM empresas
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
UNION ALL SELECT 'contratos', COUNT(*) FROM contratos
UNION ALL SELECT 'ofcs', COUNT(*) FROM ofcs
UNION ALL SELECT 'metas', COUNT(*) FROM metas
UNION ALL SELECT 'system_params', COUNT(*) FROM system_params;"

# Distribuicao de OFCs por semana
psql -d ofs_db -c "
SELECT
    date_trunc('week', data::date)::date as semana_inicio,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE tipo = 'OFS') as positivos,
    COUNT(*) FILTER (WHERE tipo = 'OFS') as negativos
FROM ofcs
GROUP BY 1 ORDER BY 1;"
```

## 7. Resumo de Senhas

| Usuario              | Login              | Senha      | Perfil      |
|----------------------|--------------------|------------|-------------|
| Administrador        | admin              | Admin@123  | admin       |
| Carlos Gestor        | gestor.sd          | Senha@123  | gestor      |
| Joao Silva           | supervisor.joao    | Senha@123  | supervisor  |
| Maria Oliveira       | supervisor.maria   | Senha@123  | supervisor  |
| Pedro Santos         | observador.pedro   | Senha@123  | observador  |
| Ana Costa            | observador.ana     | Senha@123  | observador  |

**⚠️ ALTERAR TODAS AS SENHAS ANTES DE SUBIR PARA PRODUCAO ⚠️**

## 8. Distribuicao dos Dados de Teste

50 OFCs distribuidos em 4 semanas:

| Semana | Periodo           | OFCs | OFS (+) | OFS (-) | Empresas diferentes |
|--------|-------------------|------|---------|---------|---------------------|
| 18     | 28/04 a 04/05     | 12   | 8       | 4       | 6                   |
| 19     | 05/05 a 11/05     | 13   | 9       | 4       | 8                   |
| 20     | 12/05 a 18/05     | 12   | 8       | 4       | 8                   |
| 21     | 19/05 a 25/05     | 13   | 10      | 3       | 9                   |

> Total: 35 positivos (70%) e 15 negativos (30%) — proporcao realista.

Observed by: 5 usuarios (1 gestor, 2 supervisores, 2 observadores)
Em empresas variadas (Security Dynamics, Polo Norte, G4S, ERA, Innovatec, Conin, FM, Sodexo, Engecom, P&G, Yusen, Mainpower, Aduana, Prosegur)
