"""
FastAPI Application — Sistema OFS/OFS
Security Dynamics — Sistema de Feedback Comportamental

Entry point principal da API.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.reports_router import reports_router

app = FastAPI(
    title="Sistema OFS/OFS — Security Dynamics",
    description="API de Relatórios PDF do Sistema de Feedback Comportamental",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(reports_router)


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "service": "OFS-ofs-api", "version": "1.0.0"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
