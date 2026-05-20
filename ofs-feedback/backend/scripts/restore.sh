#!/bin/bash
# ================================================================
# Sistema OFC/OFS - Security Dynamics
# Script de Restauracao de Backup (INTERATIVO)
# ================================================================
# Uso: ./restore.sh backups/daily/ofs_backup_20260513_030000.dump
# ATENCAO: SUBSTITUI TODOS OS DADOS DO BANCO
# ================================================================
set -euo pipefail

echo "============================================="
echo "  RESTAURACAO DE BANCO DE DADOS"
echo "  Sistema OFC/OFS - Security Dynamics"
echo "============================================="
echo ""

if [ $# -lt 1 ]; then
    echo "Backups disponiveis:"
    find /app/backups -name "ofs_backup_*.dump" 2>/dev/null | sort -r | head -20
    echo ""
    echo "Uso: $0 <caminho/do/backup.dump>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERRO: Arquivo nao encontrado: $BACKUP_FILE"
    exit 1
fi

echo "Arquivo : $(basename "$BACKUP_FILE")"
echo "Tamanho : $(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1 || stat -c%s "$BACKUP_FILE")"
echo "Destino : ${DB_HOST:-db}:${DB_PORT:-5432}/${DB_NAME:-ofs_feedback}"
echo ""
echo "ATENCAO: Todos os dados atuais serao SUBSTITUIDOS!"
echo ""
read -r -p "Digite 'CONFIRMAR' para continuar: " confirm
if [ "$confirm" != "CONFIRMAR" ]; then
    echo "Restauracao cancelada."
    exit 0
fi

echo ""
echo "[1/2] Verificando integridade do backup..."
if ! PGPASSWORD="${DB_PASSWORD}" pg_restore --list "$BACKUP_FILE" > /dev/null 2>&1; then
    echo "ERRO: Arquivo de backup corrompido. Abortando."
    exit 1
fi
echo "Backup integro."

echo "[2/2] Restaurando banco de dados..."
if PGPASSWORD="${DB_PASSWORD}" pg_restore \
    -h "${DB_HOST:-db}" \
    -U "${DB_USER:-ofs_app}" \
    -d "${DB_NAME:-ofs_feedback}" \
    --clean --if-exists --no-owner --no-acl \
    -v "$BACKUP_FILE"; then
    echo ""
    echo "============================================="
    echo "  RESTAURACAO CONCLUIDA COM SUCESSO!"
    echo "============================================="
else
    echo "============================================="
    echo "  ERRO NA RESTAURACAO!"
    echo "============================================="
    exit 1
fi
