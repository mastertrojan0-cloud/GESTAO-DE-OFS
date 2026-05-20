@echo off
chcp 65001 >nul
title Sistema OFC/OFS — Security Dynamics

echo.
echo  ============================================
echo    SISTEMA OFC/OFS - Security Dynamics
echo    Inicializando todos os servicos...
echo  ============================================
echo.

set "PGDIR=C:\PostgreSQL\16"
set "PGDATA=%LOCALAPPDATA%\pgdata_ofs"
set "PGLOG=%LOCALAPPDATA%\pglogs_ofs\pg.log"
set "PYTHON=C:\Program Files\Python312\python.exe"
set "BACKEND_DIR=C:\SISTEMA OFS\ofs-feedback\backend"
set "FRONTEND_DIR=C:\SISTEMA OFS\ofs-feedback\dist"
set "PATH=%PGDIR%\bin;%PGDIR%\lib;%PGDIR%\pgAdmin 4\python;C:\Program Files\Python312;%PATH%"

REM ============================================
REM 1. POSTGRESQL
REM ============================================
echo [1/3] PostgreSQL...
"%PGDIR%\bin\pg_isready.exe" -q 2>nul
if %errorlevel% neq 0 (
    echo        Iniciando...
    start "" /min "%PGDIR%\bin\pg_ctl.exe" start -D "%PGDATA%" -l "%PGLOG%"
    timeout /t 5 /nobreak >nul
    "%PGDIR%\bin\pg_isready.exe" -q 2>nul
    if %errorlevel% equ 0 (echo        PostgreSQL OK) else (echo        FALHA ao iniciar PostgreSQL && pause && exit /b 1)
) else (
    echo        PostgreSQL ja ativo
)

REM ============================================
REM 2. BACKEND
REM ============================================
echo [2/3] Backend FastAPI (porta 8000)...
start "OFS-Backend" /min /D "%BACKEND_DIR%" "%PYTHON%" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info
timeout /t 5 /nobreak >nul
echo        http://localhost:8000
echo        http://localhost:8000/api/docs

REM ============================================
REM 3. FRONTEND + PROXY
REM ============================================
echo [3/3] Frontend + API Proxy (porta 3000)...
start "OFS-Frontend" /min /D "%~dp0" "%PYTHON%" serve.py
echo        http://localhost:3000
echo        (API /api/* -> http://localhost:8000)

REM ============================================
REM PRONTO
REM ============================================
timeout /t 2 /nobreak >nul
start http://localhost:3000

echo.
echo  ============================================
echo    SISTEMA ONLINE!
echo.
echo    Frontend : http://localhost:3000
echo    Backend  : http://localhost:8000
echo    API Docs : http://localhost:8000/api/docs
echo.
echo    Login: admin / Admin@123
echo  ============================================
echo.
echo  Feche esta janela para PARAR os servicos.
echo.
echo  Pressione qualquer tecla para abrir o
echo  painel de controle...
pause >nul

:menu
cls
echo  ============================================
echo    PAINEL DE CONTROLE - OFC/OFS
echo  ============================================
echo.
echo   [1] Abrir Frontend
echo   [2] Abrir API Docs
echo   [3] Verificar status
echo   [4] PARAR todos os servicos
echo   [5] Sair (servicos continuam rodando)
echo.
set /p op="  Opcao: "

if "%op%"=="1" start http://localhost:3000
if "%op%"=="2" start http://localhost:8000/api/docs
if "%op%"=="3" goto :status
if "%op%"=="4" goto :parar
if "%op%"=="5" exit
goto :menu

:status
echo.
"%PGDIR%\bin\pg_isready.exe" -q 2>nul && echo  PostgreSQL :5432 - OK || echo  PostgreSQL :5432 - OFF
powershell -Command "try { (iwr http://localhost:8000/api/health -UseBasicParsing).Content } catch { 'off' }"
powershell -Command "try { (iwr http://localhost:3000 -UseBasicParsing).StatusCode; 'OK' } catch { 'off' }"
echo.
pause
goto :menu

:parar
echo.
echo Parando servicos...
taskkill /f /fi "WINDOWTITLE eq OFS-Backend*" 2>nul
taskkill /f /fi "WINDOWTITLE eq OFS-Frontend*" 2>nul
taskkill /f /im python.exe 2>nul
"%PGDIR%\bin\pg_ctl.exe" stop -D "%PGDATA%" 2>nul
echo Todos os servicos parados.
pause
exit
