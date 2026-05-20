@echo off
REM Parar todos os servicos do Sistema OFC/OFS
echo Parando Sistema OFC/OFS...

REM Para backend (uvicorn)
taskkill /f /fi "WINDOWTITLE eq OFS-Backend*" 2>nul
taskkill /f /im python.exe /fi "WINDOWTITLE eq uvicorn*" 2>nul

REM Para frontend
taskkill /f /fi "WINDOWTITLE eq OFS-Frontend*" 2>nul

REM Para PostgreSQL
echo Parando PostgreSQL...
"C:\PostgreSQL\16\bin\pg_ctl.exe" stop -D "%LOCALAPPDATA%\pgdata_ofs" 2>nul

echo Sistema parado.
pause
