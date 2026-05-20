# ================================================================
# Sistema OFS/OFS - Security Dynamics
# COMANDOS ESSENCIAIS DE OPERACAO
# ================================================================

# ------------------------------------------------------------------
# DEPLOY INICIAL (primeira vez)
# ------------------------------------------------------------------
# 1. Gerar secret JWT
#    openssl rand -hex 32
# 2. Copiar .env.example → .env e preencher senhas + JWT_SECRET
# 3. Build do backend (executar em maquina COM internet para baixar
#    dependencias offline):
#    docker compose build backend
# 4. Build do frontend:
#    cd frontend && npm ci && npm run build && cd ..
# 5. Subir tudo:
#    docker compose up -d
# 6. Verificar:
#    bash scripts/health-check.sh

# ------------------------------------------------------------------
# DEPLOY (atualizacao de codigo)
# ------------------------------------------------------------------
#    cd frontend && npm ci && npm run build && cd ..
#    docker compose build backend
#    docker compose up -d

# ------------------------------------------------------------------
# COMANDOS DIARIOS
# ------------------------------------------------------------------

# Subir ambiente
#    docker compose up -d

# Parar ambiente
#    docker compose stop

# Reiniciar ambiente
#    docker compose restart

# Status dos containers
#    docker compose ps

# Ver logs de todos os servicos
#    docker compose logs --tail=100

# Ver logs do backend apenas
#    docker compose logs backend --tail=50 -f

# Ver logs do nginx
#    docker compose logs nginx --tail=50

# Ver logs do banco
#    docker compose logs db --tail=50

# Abrir shell no backend
#    docker compose exec backend bash

# Abrir psql no banco
#    docker compose exec db psql -U ofs_app -d ofs_feedback

# ------------------------------------------------------------------
# BACKUP
# ------------------------------------------------------------------

# Backup manual imediato
#    docker compose exec backend bash /app/scripts/backup.sh

# Restaurar backup
#    bash scripts/restore.sh backups/daily/ofs_backup_YYYYMMDD_HHMMSS.dump

# Listar backups disponiveis
#    find backups/ -name "ofs_backup_*.dump" -printf "%TFT%TT %10sB %p\n" | sort -r | head -20

# ------------------------------------------------------------------
# HEALTH CHECK
# ------------------------------------------------------------------

# Verificacao completa do ambiente
#    bash scripts/health-check.sh

# Verificar apenas API backend
#    curl -s http://localhost/api/health | python -m json.tool

# Verificar status do PostgreSQL
#    docker compose exec db pg_isready -U ofs_app

# ------------------------------------------------------------------
# MANUTENCAO
# ------------------------------------------------------------------

# Remover containers parados e imagens nao usadas
#    docker system prune -a

# Ver uso de disco dos volumes
#    docker system df -v

# Backup + rebuild completo (emergencia)
#    docker compose exec backend bash /app/scripts/backup.sh
#    docker compose down
#    docker compose build --no-cache backend
#    docker compose up -d
