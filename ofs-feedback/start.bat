@echo off
REM ============================================================
REM  SISTEMA OFC/OFS — Security Dynamics
REM  Script de Inicializacao Completa
REM ============================================================
echo.
echo  ========================================
echo   SISTEMA OFC/OFS - Security Dynamics
echo   Inicializando...
echo  ========================================
echo.

set "PGDIR=C:\PostgreSQL\16"
set "PGDATA=%LOCALAPPDATA%\pgdata_ofs"
set "PGLOG=%LOCALAPPDATA%\pglogs_ofs\pg.log"
set "BACKEND_DIR=%~dp0backend"
set "FRONTEND_DIR=%~dp0dist"

REM 1. PostgreSQL
echo [1/3] Verificando PostgreSQL...
"%PGDIR%\bin\pg_isready.exe" -h localhost -p 5432 -q
if %errorlevel% neq 0 (
    echo        Iniciando PostgreSQL...
    set "PATH=%PGDIR%\bin;%PGDIR%\lib;C:\Program Files\Python312;%PATH%"
    start /b "" "%PGDIR%\bin\pg_ctl.exe" start -D "%PGDATA%" -l "%PGLOG%"
    timeout /t 4 /nobreak >nul
    "%PGDIR%\bin\pg_isready.exe" -h localhost -p 5432 -q
    if %errorlevel% equ 0 (echo        PostgreSQL OK) else (echo        ERRO: PostgreSQL nao iniciou && pause && exit /b 1)
) else (
    echo        PostgreSQL ja esta rodando
)

REM 2. Backend
echo [2/3] Iniciando Backend (FastAPI)...
start "OFS-Backend" /b cmd /c "cd /d "%BACKEND_DIR%" && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
timeout /t 3 /nobreak >nul
echo        Backend em http://localhost:8000

REM 3. Frontend
echo [3/3] Servindo Frontend (React)...
if exist "%FRONTEND_DIR%\index.html" (
    start "OFS-Frontend" /b cmd /c "cd /d "%FRONTEND_DIR%" && python -m http.server 3000"
    echo        Frontend em http://localhost:3000
) else (
    echo        AVISO: Frontend nao buildado. Execute: npm run build
    echo        Iniciando em modo dev...
    start "OFS-Frontend-Dev" /b cmd /c "cd /d "%~dp0" && npx vite --port 3000"
    echo        Frontend dev em http://localhost:3000
)

echo.
echo  ========================================
echo   SISTEMA PRONTO!
echo.
echo   Frontend : http://localhost:3000
echo   Backend  : http://localhost:8000
echo   API Docs : http://localhost:8000/api/docs
echo   Health   : http://localhost:8000/api/health
echo.
echo   Login: admin / Admin@123
echo  ========================================
echo.
echo  Feche esta janela para PARAR todos os servicos.
pause
