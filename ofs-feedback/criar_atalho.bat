@echo off
chcp 65001 >nul
title Criar Atalho na Area de Trabalho - GESTAO DE OFS

echo.
echo  ============================================
echo    CRIAR ATALHO NA AREA DE TRABALHO
echo    GESTAO DE OFS
echo  ============================================
echo.
echo  Gerando icone customizado (escudo OFS) e
echo  criando atalho na sua Area de Trabalho...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\gerar_icone_e_atalho.ps1"

if %errorlevel% neq 0 (
    echo.
    echo  [ERRO] Falha ao criar o atalho. Veja a mensagem acima.
    pause
    exit /b 1
)

echo.
echo  ============================================
echo    ATALHO CRIADO COM SUCESSO!
echo.
echo    Procure na Area de Trabalho:
echo        GESTAO DE OFS
echo.
echo    Duplo clique sobe todo o sistema.
echo  ============================================
echo.
pause
