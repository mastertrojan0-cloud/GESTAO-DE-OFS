#!/bin/bash
# ================================================================
# Sistema OFC/OFS - Security Dynamics
# Script de Backup Automatico do PostgreSQL
# ================================================================
# Executar dentro do container backend (APScheduler) ou via cron
# Uso manual: docker compose exec backend bash /app/scripts/backup.sh
# ================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
DAILY_DIR="$BACKUP_DIR/daily"
WEEKLY_DIR="$BACKUP_DIR/weekly"
MONTHLY_DIR="$BACKUP_DIR/monthly"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="ofs_backup_${TIMESTAMP}.dump"
LOG_FILE="$BACKUP_DIR/backup.log"
RETENTION_DAILY="${BACKUP_RETENTION_DAILY:-30}"
RETENTION_WEEKLY="${BACKUP_RETENTION_WEEKLY:-12}"
RETENTION_MONTHLY="${BACKUP_RETENTION_MONTHLY:-12}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

mkdir -p "$DAILY_DIR" "$WEEKLY_DIR" "$MONTHLY_DIR"

log "Iniciando backup: $FILENAME"

# Executa pg_dump (formato customizado comprimido)
if ! PGPASSWORD="${DB_PASSWORD}" pg_dump \
    -h "${DB_HOST:-db}" \
    -U "${DB_USER:-ofs_app}" \
    -d "${DB_NAME:-ofs_feedback}" \
    -Fc -v -f "$DAILY_DIR/$FILENAME" 2>> "$LOG_FILE"; then
    log "ERRO: pg_dump falhou."
    exit 1
fi

# Verifica integridade do backup
if ! PGPASSWORD="${DB_PASSWORD}" pg_restore --list "$DAILY_DIR/$FILENAME" > /dev/null 2>&1; then
    log "ERRO: Backup corrompido - removendo $FILENAME"
    rm -f "$DAILY_DIR/$FILENAME"
    exit 1
fi

SIZE=$(stat -c%s "$DAILY_DIR/$FILENAME" 2>/dev/null || echo 0)
log "Backup OK: $FILENAME (${SIZE} bytes)"

# Copia semanal (domingo = dia 7)
if [ "$(date +%u)" -eq 7 ]; then
    cp "$DAILY_DIR/$FILENAME" "$WEEKLY_DIR/$FILENAME"
    log "Backup semanal copiado."
fi

# Copia mensal (dia 1)
if [ "$(date +%d)" = "01" ]; then
    cp "$DAILY_DIR/$FILENAME" "$MONTHLY_DIR/$FILENAME"
    log "Backup mensal copiado."
fi

# Rotacao de backups antigos
find "$DAILY_DIR" -name "ofs_backup_*.dump" -mtime "+${RETENTION_DAILY}" -delete 2>/dev/null || true
find "$WEEKLY_DIR" -name "ofs_backup_*.dump" -mtime "+$((RETENTION_WEEKLY * 7))" -delete 2>/dev/null || true
find "$MONTHLY_DIR" -name "ofs_backup_*.dump" -mtime "+$((RETENTION_MONTHLY * 30))" -delete 2>/dev/null || true
log "Rotacao concluida."

# Copia para NAS (se configurado)
if [ -n "${NAS_BACKUP_PATH:-}" ] && [ -d "$NAS_BACKUP_PATH" ]; then
    cp "$DAILY_DIR/$FILENAME" "$NAS_BACKUP_PATH/"
    log "Copia para NAS: $NAS_BACKUP_PATH/$FILENAME"
fi

log "Backup finalizado com sucesso."
