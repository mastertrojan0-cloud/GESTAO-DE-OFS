#!/bin/bash
# ============================================================
# Security Dynamics - OFS Feedback System
# Script de Disaster Recovery - Reconstrucao do Ambiente
# ============================================================
# Uso: ./disaster_recovery.sh <backup_file.dump>
# Este script:
#   1. Instala Docker (se necessario)
#   2. Sobe containers
#   3. Restaura banco de dados
#   4. Verifica ambiente
# ============================================================

set -euo pipefail

echo "========================================"
echo "  DISASTER RECOVERY - OFS FEEDBACK"
echo "  Security Dynamics"
echo "========================================"
echo ""

# 1. Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "Docker nao encontrado. Instale o Docker e Docker Compose primeiro."
    echo "Guia: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker compose version &> /dev/null 2>&1 && ! docker-compose --version &> /dev/null 2>&1; then
    echo "Docker Compose nao encontrado."
    exit 1
fi

COMPOSE_CMD="docker compose"
if ! docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
fi

# 2. Verificar arquivos essenciais
if [ ! -f "docker-compose.yml" ]; then
    echo "ERRO: docker-compose.yml nao encontrado no diretorio atual."
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "ERRO: .env nao encontrado. Copie do backup seguro."
    exit 1
fi

# 3. Subir banco de dados primeiro
echo "[1/4] Iniciando banco de dados..."
$COMPOSE_CMD up -d db
echo "Aguardando PostgreSQL estar pronto..."
sleep 10

# 4. Restaurar backup
if [ $# -ge 1 ] && [ -f "$1" ]; then
    echo "[2/4] Restaurando backup: $1"
    docker cp "$1" "$($COMPOSE_CMD ps -q db):/tmp/backup.dump"
    $COMPOSE_CMD exec -T db bash -c "
        PGPASSWORD=\"\$POSTGRES_PASSWORD\" pg_restore \\
            -U \"\$POSTGRES_USER\" \\
            -d \"\$POSTGRES_DB\" \\
            --clean \\
            --if-exists \\
            --no-owner \\
            /tmp/backup.dump
    " && echo "Backup restaurado com sucesso." || echo "AVISO: Verifique a restauracao manualmente."
else
    echo "[2/4] Nenhum backup fornecido. Pulando restauracao."
    echo "Para restaurar um backup, execute: $0 <caminho/do/backup.dump>"
fi

# 5. Subir todos os servicos
echo "[3/4] Subindo todos os servicos..."
$COMPOSE_CMD up -d
echo "Aguardando servicos iniciarem..."
sleep 15

# 6. Verificar saude dos servicos
echo "[4/4] Verificando ambiente..."
if $COMPOSE_CMD ps | grep -q "Up"; then
    echo "Servicos em execucao:"
    $COMPOSE_CMD ps
else
    echo "ERRO: Servicos nao iniciaram corretamente."
    echo "Verifique logs: $COMPOSE_CMD logs"
    exit 1
fi

echo ""
echo "========================================"
echo "  RECUPERACAO CONCLUIDA!"
echo "========================================"
echo ""
echo "Verificacoes manuais recomendadas:"
echo "  1. Acessar http://localhost e realizar login"
echo "  2. Verificar listagem de OFCs"
echo "  3. Testar geracao de relatorio PDF"
echo "  4. Verificar metricas e graficos"
echo ""
echo "RTO: $(date '+%Y-%m-%d %H:%M:%S')"
