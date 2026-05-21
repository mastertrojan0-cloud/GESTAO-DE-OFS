@echo off
chcp 65001 >nul
title Desinstalar Autostart - GESTAO DE OFS

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERRO] Este script precisa ser executado como ADMINISTRADOR.
    echo.
    pause
    exit /b 1
)

set "TASKNAME=GESTAO_DE_OFS_Autostart"

echo.
echo  Removendo tarefa agendada "%TASKNAME%"...
schtasks /Query /TN "%TASKNAME%" >nul 2>&1
if %errorlevel% neq 0 (
    echo  Tarefa nao encontrada. Nada a fazer.
) else (
    schtasks /Delete /TN "%TASKNAME%" /F
    echo  Autostart desinstalado.
)
echo.
pause
