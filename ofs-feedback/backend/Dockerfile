# ================================================================
# ESTAGIO 1: Build — Download offline de dependencias Python
# (executar em maquina COM internet para gerar imagem base)
# ================================================================
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip download -r requirements.txt -d /offline-packages

# ================================================================
# ESTAGIO 2: Producao — Instalacao offline, non-root
# ================================================================
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-dejavu-core \
    fonts-liberation \
    fonts-liberation2 \
    postgresql-client-16 \
    curl \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN groupadd -r appuser && useradd -r -g appuser -d /app appuser

WORKDIR /app

COPY --from=builder /offline-packages /offline-packages
COPY requirements.txt .
RUN pip install --no-index --find-links /offline-packages -r requirements.txt \
    && rm -rf /offline-packages

COPY . .

RUN mkdir -p /app/reports /app/backups /tmp \
    && chown -R appuser:appuser /app /tmp

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "4", "--log-level", "info"]
