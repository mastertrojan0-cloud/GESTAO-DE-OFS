@echo off
chcp 65001 >nul
title Setup - GESTAO DE OFS (Primeira Instalacao)

echo.
echo  ============================================
echo    SETUP PRIMEIRA VEZ - GESTAO DE OFS
echo    Configurar PostgreSQL + Database + Schema
echo  ============================================
echo.

REM Verifica se ja foi rodado antes
if exist "%LOCALAPPDATA%\gestao_ofs.setup_ok" (
    echo  [INFO] Setup ja foi rodado anteriormente.
    echo  Se quiser refazer, delete: %LOCALAPPDATA%\gestao_ofs.setup_ok
    pause
    exit /b 0
)

set "PGDIR=C:\PostgreSQL\16"
set "PGDATA=%LOCALAPPDATA%\pgdata_ofs"

REM ============================================
REM 1. Verifica PostgreSQL
REM ============================================
echo [1/4] Verificando PostgreSQL...
if not exist "%PGDIR%\bin\psql.exe" (
    echo  [ERRO] PostgreSQL nao encontrado em %PGDIR%
    echo  Baixe em: https://www.postgresql.org/download/windows/
    pause
    exit /b 1
)

"%PGDIR%\bin\pg_isready.exe" -q 2>nul
if %errorlevel% neq 0 (
    echo  Iniciando PostgreSQL...
    start "" /min "%PGDIR%\bin\pg_ctl.exe" start -D "%PGDATA%" -l "%LOCALAPPDATA%\pglogs_ofs\pg.log"
    timeout /t 5 /nobreak >nul
)
echo  OK

REM ============================================
REM 2. Cria role ofs_app e database ofs_db
REM ============================================
echo [2/4] Criando role e database...

REM Script SQL temporario
set "SQLFILE=%TEMP%\setup_ofs.sql"
(
    echo CREATE ROLE ofs_app WITH LOGIN PASSWORD 'ofs_app_2026';
    echo ALTER ROLE ofs_app CREATEDB;
    echo ALTER ROLE ofs_app SUPERUSER;
) > "%SQLFILE%"

REM Executa como superuser
"%PGDIR%\bin\psql.exe" -U postgres -h localhost -f "%SQLFILE%" >nul 2>&1
del "%SQLFILE%"

REM Cria database (ignora se ja existe)
"%PGDIR%\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE ofs_db OWNER ofs_app;" >nul 2>&1
echo  OK

REM ============================================
REM 3. Roda DDL (schema + seed)
REM ============================================
echo [3/4] Criando schema e carregando dados...
set "DDLFILE=%~dp0..\ddl_sistema_ofs.sql"

if exist "%DDLFILE%" (
    "%PGDIR%\bin\psql.exe" -U ofs_app -h localhost -d ofs_db -f "%DDLFILE%" >nul 2>&1
    echo  OK
) else (
    echo  [AVISO] DDL nao encontrado: %DDLFILE%
)

REM ============================================
REM 4. npm install (se necessario)
REM ============================================
echo [4/4] Instalando dependencias Node...
if not exist "%~dp0node_modules" (
    cd /d "%~dp0"
    if exist package.json (
        call npm install >nul 2>&1
    )
)
echo  OK

REM ============================================
REM Marca como concluido
REM ============================================
echo. > "%LOCALAPPDATA%\gestao_ofs.setup_ok"

echo.
echo  ============================================
echo    SETUP CONCLUIDO!
echo.
echo    Proximas etapas (recomendado):
echo.
echo    1. Configurar Rede:
echo       configurar_rede.bat
echo.
echo    2. Criar Atalho na Area de Trabalho:
echo       criar_atalho.bat
echo.
echo    3. Instalar Autostart (opcional):
echo       instalar_autostart.bat
echo.
echo    4. Iniciar Sistema:
echo       iniciar.bat
echo.
echo  ============================================
echo.
pause
