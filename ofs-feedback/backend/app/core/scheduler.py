import subprocess
import os
import logging
from datetime import datetime
from pathlib import Path
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from app.core.config import settings

scheduler = AsyncIOScheduler()
logger = logging.getLogger(__name__)


async def _run_backup():
    from app.db.session import AsyncSessionLocal
    from sqlalchemy import text

    timestamp = datetime.now()
    filename = f"ofs_backup_{timestamp:%Y%m%d_%H%M%S}.dump"
    daily_dir = Path(settings.BACKUP_DIR) / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True)
    filepath = daily_dir / filename

    cmd = [
        "pg_dump",
        "-h", settings.DB_HOST,
        "-U", settings.DB_USER,
        "-d", settings.DB_NAME,
        "-Fc", "-f", str(filepath),
    ]
    env = {**os.environ, "PGPASSWORD": settings.DB_PASSWORD}

    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    status = "success" if result.returncode == 0 else "failed"
    size = filepath.stat().st_size if filepath.exists() else 0
    error = result.stderr[:500] if result.returncode != 0 else None

    try:
        async with AsyncSessionLocal() as session:
            await session.execute(
                text(
                    "INSERT INTO backups (filename, file_path, size_bytes, type, status, error_message, created_at) "
                    "VALUES (:fn, :fp, :sz, 'auto', :st, :err, :ts)"
                ),
                {
                    "fn": filename,
                    "fp": str(filepath),
                    "sz": size,
                    "st": status,
                    "err": error,
                    "ts": timestamp,
                },
            )
            await session.commit()
    except Exception:
        logger.exception("Falha ao registrar backup no banco de dados")

    for f in daily_dir.glob("ofs_backup_*.dump"):
        age_days = (datetime.now() - datetime.fromtimestamp(f.stat().st_mtime)).days
        if age_days > settings.BACKUP_RETENTION_DAILY:
            f.unlink(missing_ok=True)

    if timestamp.weekday() == 6:
        weekly_dir = Path(settings.BACKUP_DIR) / "weekly"
        weekly_dir.mkdir(parents=True, exist_ok=True)
        filepath.replace(weekly_dir / filename)

    if timestamp.day == 1:
        monthly_dir = Path(settings.BACKUP_DIR) / "monthly"
        monthly_dir.mkdir(parents=True, exist_ok=True)
        filepath.replace(monthly_dir / filename)


async def _cleanup_old_reports():
    """Remove PDFs/XLSX gerados ha mais de 90 dias e zera registros da tabela reports."""
    reports_dir = Path(os.environ.get("REPORTS_DIR", "/app/reports"))
    if not reports_dir.exists():
        return

    cutoff_days = 90
    now = datetime.now()
    deleted_count = 0

    for subdir in reports_dir.glob("**"):
        if not subdir.is_dir():
            continue
        for report_file in subdir.glob("*"):
            if report_file.suffix.lower() in (".pdf", ".xlsx"):
                age_days = (now - datetime.fromtimestamp(report_file.stat().st_mtime)).days
                if age_days > cutoff_days:
                    try:
                        report_file.unlink()
                        deleted_count += 1
                    except OSError:
                        pass

    if deleted_count > 0:
        logger.info(f"Limpeza de relatorios: {deleted_count} arquivos removidos (>{cutoff_days} dias)")

    from app.db.session import AsyncSessionLocal
    from sqlalchemy import text
    try:
        cutoff_date = now.isoformat()
        async with AsyncSessionLocal() as session:
            result = await session.execute(
                text(
                    "DELETE FROM reports WHERE created_at < :cutoff - INTERVAL '90 days'"
                ),
                {"cutoff": cutoff_date},
            )
            await session.commit()
            if result.rowcount and result.rowcount > 0:
                logger.info(f"Limpeza de tabela reports: {result.rowcount} registros removidos (>{cutoff_days} dias)")
    except Exception as e:
        logger.warning(f"Falha ao limpar tabela reports: {e}")


def init_scheduler():
    scheduler.add_job(
        _run_backup,
        trigger=CronTrigger(hour=3, minute=0),
        id="backup_diario",
        name="Backup diario do PostgreSQL",
        replace_existing=True,
    )
    scheduler.add_job(
        _cleanup_old_reports,
        trigger=CronTrigger(hour=4, minute=0),
        id="cleanup_reports",
        name="Limpeza automatica de relatorios antigos (90 dias)",
        replace_existing=True,
    )
    scheduler.start()
