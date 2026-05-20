#!/bin/bash
# ================================================================
# Sistema OFC/OFS - Security Dynamics
# Script de Restauracao de Backup (INTERATIVO)
# ================================================================
# Uso: ./restore.sh backups/daily/ofs_backup_20260513_030000.dump
# ATENCAO: SUBSTITUI TODOS OS DADOS DO BANCO
# ================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "============================================="
echo -e "${RED}  RESTAURACAO DE BANCO DE DADOS${NC}"
echo "  Sistema OFC/OFS - Security Dynamics"
echo "============================================="
echo ""

if [ $# -lt 1 ]; then
    echo "Backups disponiveis:"
    find . -path "*/backups/*" -name "ofs_backup_*.dump" -printf "  %TFT%TT %sB %p\n" 2>/dev/null | sort -r | head -20
    echo ""
    echo "Uso: $0 <caminho/do/backup.dump>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}ERRO: Arquivo nao encontrado: $BACKUP_FILE${NC}"
    exit 1
fi

echo "Arquivo : $(basename "$BACKUP_FILE")"
echo "Tamanho : $(du -h "$BACKUP_FILE" | cut -f1)"
echo "Destino : ${DB_HOST:-db}:${DB_PORT:-5432}/${DB_NAME:-ofs_feedback}"
echo ""
echo -e "${RED}ATENCAO: Todos os dados atuais serao SUBSTITUIDOS!${NC}"
echo ""
read -r -p "Digite 'CONFIRMAR' para continuar: " confirm
if [ "$confirm" != "CONFIRMAR" ]; then
    echo "Restauracao cancelada."
    exit 0
fi

echo ""
echo "[1/3] Verificando integridade do backup..."
if ! PGPASSWORD="${DB_PASSWORD}" pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1; then
    echo -e "${RED}ERRO: Arquivo de backup corrompido. Abortando.${NC}"
    exit 1
fi
echo "Backup integro."

echo "[2/3] Parando aplicacao..."
docker compose stop backend

echo "[3/3] Restaurando banco de dados..."
if PGPASSWORD="${DB_PASSWORD}" pg_restore \
    -h "${DB_HOST:-db}" \
    -U "${DB_USER:-ofs_app}" \
    -d "${DB_NAME:-ofs_feedback}" \
    --clean --if-exists --no-owner --no-acl \
    -v "$BACKUP_FILE"; then

    echo ""
    echo "Reiniciando aplicacao..."
    docker compose start backend
    sleep 5

    echo ""
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}  RESTAURACAO CONCLUIDA COM SUCESSO!${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo ""
    docker compose ps
else
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}  ERRO NA RESTAURACAO!${NC}"
    echo -e "${RED}=============================================${NC}"
    echo "Verifique os logs e tente novamente."
    docker compose start backend
    exit 1
fi
