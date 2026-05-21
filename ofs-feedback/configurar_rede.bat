@echo off
chcp 65001 >nul
title Configurar Rede - GESTAO DE OFS

REM ============================================
REM Abre as portas 3000 (frontend) e 8000 (API)
REM no Windows Firewall para acesso pela rede
REM local (LAN) e via Tailscale.
REM
REM Requer: executar como Administrador.
REM ============================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERRO] Este script precisa ser executado como ADMINISTRADOR.
    echo.
    pause
    exit /b 1
)

echo.
echo  ============================================
echo    CONFIGURAR REDE - GESTAO DE OFS
echo  ============================================
echo.

REM ----- Firewall -----
echo  [1/3] Liberando portas 3000 e 8000 no firewall...

netsh advfirewall firewall delete rule name="GESTAO OFS - Frontend 3000" >nul 2>&1
netsh advfirewall firewall delete rule name="GESTAO OFS - Backend 8000" >nul 2>&1

netsh advfirewall firewall add rule name="GESTAO OFS - Frontend 3000" dir=in action=allow protocol=TCP localport=3000 profile=private,domain >nul
netsh advfirewall firewall add rule name="GESTAO OFS - Backend 8000"  dir=in action=allow protocol=TCP localport=8000 profile=private,domain >nul

if %errorlevel% equ 0 (
    echo        OK - portas liberadas para perfis Private e Domain.
) else (
    echo        FALHA ao configurar o firewall.
)
echo.

REM ----- IPs LAN -----
echo  [2/3] IPs da rede local (LAN):
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    set "ip=%%a"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    echo        http://!ip!:3000
    endlocal
)
echo.

REM ----- Tailscale -----
echo  [3/3] Tailscale:
where tailscale >nul 2>&1
if %errorlevel% neq 0 (
    echo        Tailscale NAO instalado.
    echo        Baixe em: https://tailscale.com/download/windows
    echo        Depois rode novamente este script.
) else (
    echo        Tailscale detectado. IPs desta maquina na tailnet:
    for /f "tokens=*" %%a in ('tailscale ip 2^>nul') do (
        echo            http://%%a:3000
    )
    echo.
    echo        Nome MagicDNS desta maquina:
    for /f "tokens=*" %%a in ('tailscale status --self --json 2^>nul ^| findstr /C:"DNSName"') do (
        echo            %%a
    )
    echo.
    echo        Dica: na maquina cliente instale o Tailscale, faca login
    echo        na mesma tailnet e acesse pelos enderecos acima.
)
echo.

echo  ============================================
echo    CONFIGURACAO CONCLUIDA
echo.
echo    Frontend : http://localhost:3000
echo    Backend  : http://localhost:8000
echo  ============================================
echo.
pause
