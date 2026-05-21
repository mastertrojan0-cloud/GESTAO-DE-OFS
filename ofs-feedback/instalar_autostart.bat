@echo off
chcp 65001 >nul
title Instalar Autostart - GESTAO DE OFS

REM ============================================
REM Registra uma tarefa agendada que sobe todos
REM os servicos (PostgreSQL, FastAPI, Frontend)
REM automaticamente no logon do Windows.
REM
REM Requer: executar como Administrador.
REM ============================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERRO] Este script precisa ser executado como ADMINISTRADOR.
    echo  Clique com o botao direito e escolha "Executar como administrador".
    echo.
    pause
    exit /b 1
)

set "TASKNAME=GESTAO_DE_OFS_Autostart"
set "VBSPATH=%~dp0iniciar_silencioso.vbs"

echo.
echo  ============================================
echo    INSTALAR AUTOSTART - GESTAO DE OFS
echo  ============================================
echo.
echo  Tarefa : %TASKNAME%
echo  Script : %VBSPATH%
echo  Gatilho: logon de qualquer usuario
echo.

REM Remove tarefa antiga, se existir
schtasks /Query /TN "%TASKNAME%" >nul 2>&1
if %errorlevel% equ 0 (
    echo  Removendo tarefa anterior...
    schtasks /Delete /TN "%TASKNAME%" /F >nul
)

REM Cria a tarefa: roda no logon, com privilegios mais altos, oculta
schtasks /Create ^
    /TN "%TASKNAME%" ^
    /TR "wscript.exe \"%VBSPATH%\"" ^
    /SC ONLOGON ^
    /RL HIGHEST ^
    /F

if %errorlevel% neq 0 (
    echo.
    echo  [ERRO] Falha ao criar a tarefa agendada.
    pause
    exit /b 1
)

echo.
echo  ============================================
echo    AUTOSTART INSTALADO COM SUCESSO!
echo.
echo    A partir do proximo logon do Windows os
echo    servicos sobem sozinhos em background.
echo.
echo    Para testar agora sem reiniciar:
echo        schtasks /Run /TN "%TASKNAME%"
echo.
echo    Para remover depois, execute:
echo        desinstalar_autostart.bat
echo  ============================================
echo.
pause
