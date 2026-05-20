# Requisitos Minimos do Servidor
# Sistema OFS/OFS - Security Dynamics

## Cenario Base (10-50 usuarios simultaneos, ~50k OFCs/ano)

| Recurso    | Minimo         | Recomendado     | Justificativa                              |
|------------|----------------|-----------------|---------------------------------------------|
| CPU        | 2 vCPUs        | 4 vCPUs         | 4 workers Uvicorn + PostgreSQL + WeasyPrint |
| RAM        | 4 GB           | 8 GB            | 256MB shared_buffers + 4 workers Python + OS|
| Disco      | 50 GB SSD      | 100 GB SSD      | pgdata 5GB/ano + backups 30d + reports      |
| SO         | Ubuntu 22.04+ / Windows Server 2019+ | | Docker Engine                              |
| Docker     | 24+            | latest stable   | Compose plugin incluso                      |
| Rede       | IP fixo local   | 192.168.x.x     | Acesso intranet apenas                      |

## Estimativa de Crescimento de Disco

| Componente       | Tam. Inicial | Crescimento Anual | Notas                         |
|------------------|-------------|-------------------|-------------------------------|
| pgdata           | 1 GB        | +5 GB             | ~50k OFCs + audit + indices   |
| backups (daily)  | 2 GB        | +20 GB            | 30 dias retencao, ~200MB/dia  |
| reports (PDFs)   | 50 MB       | +2 GB             | ~500 PDFs/ano, ~4MB cada      |

## O que NAO e necessario

| Item              | Motivo                                            |
|-------------------|---------------------------------------------------|
| GPU               | Sem ML / processamento grafico                    |
| Internet          | Sistema 100% offline / intranet                   |
| CDN               | Todos assets (fontes, CSS, JS) sao locais         |
| Load Balancer     | Monolito modular, single-server suficiente        |
| Redis / Memcached | Cachetools.TTLCache em memoria basta para MVP     |
| Fila (Celery/RQ)  | Geracao de PDF sincrona aceitavel no MVP          |
