#!/bin/bash
# ================================================================
# Sistema OFC/OFS - Security Dynamics
# Script de Disaster Recovery
# ================================================================
# Uso: ./disaster_recovery.sh [backup_file.dump]
# ================================================================
set -euo pipefail

echo "============================================="
echo "  DISASTER RECOVERY - OFS"
echo "  Security Dynamics"
echo "============================================="

if ! command -v docker &> /dev/null; then
    echo "Docker nao encontrado. Instale primeiro."
    exit 1
fi

DOCKER_COMPOSE="docker compose"
if ! docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
fi

[ ! -f "docker-compose.yml" ] && { echo "ERRO: docker-compose.yml nao encontrado."; exit 1; }
[ ! -f ".env" ] && { echo "ERRO: .env nao encontrado. Copie do backup seguro."; exit 1; }

echo "[1/4] Subindo banco de dados..."
$DOCKER_COMPOSE up -d db
echo "Aguardando PostgreSQL..."
sleep 10

if [ $# -ge 1 ] && [ -f "$1" ]; then
    echo "[2/4] Restaurando backup: $1"
    docker cp "$1" "$($DOCKER_COMPOSE ps -q db):/tmp/backup.dump"
    $DOCKER_COMPOSE exec -T db bash -c '
        PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
            -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
            --clean --if-exists --no-owner /tmp/backup.dump
    ' && echo "Backup restaurado." || echo "AVISO: Verifique a restauracao."
else
    echo "[2/4] Nenhum backup fornecido. Pulando restauracao."
fi

echo "[3/4] Subindo todos os servicos..."
$DOCKER_COMPOSE up -d
sleep 15

echo "[4/4] Verificando ambiente..."
$DOCKER_COMPOSE ps
echo ""
echo "============================================="
echo "  RECUPERACAO CONCLUIDA"
echo "============================================="
echo "Acesse http://localhost e realize login."
echo "RTO: $(date '+%Y-%m-%d %H:%M:%S')"
