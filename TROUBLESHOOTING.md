# Troubleshooting — GESTÃO DE OFS

Problemas comuns e soluções rápidas.

---

## ❌ "Não acessa em nenhum lugar" / "Timeout na porta 3000 ou 8000"

### Causa: Serviços não estão rodando

**Solução rápida:**
```cmd
cd ofs-feedback
taskkill /F /IM python.exe
setup_primeira_vez.bat
iniciar.bat
```

### Verificar status:
```cmd
netstat -ano | findstr ":3000 :8000 :5432"
```

Deve ver algo como:
```
TCP    0.0.0.0:3000    LISTENING
TCP    0.0.0.0:8000    LISTENING
TCP    127.0.0.1:5432  LISTENING
```

---

## ❌ "Não existe a função de banco de dados (role) monitorador" / "FATAL: role não existe"

### Causa: Setup de PostgreSQL não foi rodado

**Solução:**
```cmd
cd ofs-feedback
setup_primeira_vez.bat    # Cria role ofs_app, database ofs_db, schema
```

**Manual (se setup.bat falhar):**
```cmd
cd ofs-feedback

REM Abre terminal PostgreSQL
"C:\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost

REM Dentro do psql:
CREATE ROLE ofs_app WITH LOGIN PASSWORD 'ofs_app_2026';
ALTER ROLE ofs_app CREATEUSER;
CREATE DATABASE ofs_db OWNER ofs_app;
\q

REM De volta ao cmd, carrega schema:
"C:\PostgreSQL\16\bin\psql.exe" -U ofs_app -h localhost -d ofs_db -f "..\ddl_sistema_ofs.sql"
```

---

## ❌ Porta 8000 ou 3000 já em uso / "Address already in use"

### Causa: Processo antigo não foi finalizado

**Solução rápida:**
```cmd
taskkill /F /IM python.exe
taskkill /F /IM node.exe
```

Depois tenta de novo:
```cmd
cd ofs-feedback
iniciar.bat
```

---

## ❌ Backend conecta mas "500 Internal Server Error"

### Causas comuns:

1. **Variável de ambiente não está configurada:**
   ```cmd
   cd ofs-feedback\backend
   type .env
   ```
   Deve ter:
   ```
   DB_HOST=localhost
   DB_PORT=5432
   DB_USER=ofs_app
   DB_PASSWORD=ofs_app_2026
   DB_NAME=ofs_db
   ```

2. **Banco de dados não tem as tabelas:**
   ```cmd
   cd ofs-feedback
   setup_primeira_vez.bat    # Roda DDL novamente
   ```

3. **Privilégios insuficientes na role:**
   ```cmd
   "C:\PostgreSQL\16\bin\psql.exe" -U postgres -h localhost
   ALTER ROLE ofs_app SUPERUSER;
   \q
   ```

---

## ❌ Frontend carrega mas "ERR_CONNECTION_REFUSED" em requisições

### Causa: Backend não está respondendo ou proxy errado

**Verificar:**
```cmd
curl http://localhost:8000/api/health
```

Se falhar, veja logs do backend em `iniciar.bat` (janela de console).

**Solução:**
1. Mata backend: `taskkill /F /IM python.exe`
2. Rodar novamente:
   ```cmd
   cd ofs-feedback\backend
   "C:\Program Files\Python312\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
3. Vê se ele printa:
   ```
   Uvicorn running on http://0.0.0.0:8000
   ```

---

## ❌ Login falha / "Credenciais inválidas"

### Usuário admin padrão:
```
username: admin
password: Admin@123
```

Se não funciona:
1. Verifica se seed foi carregado:
   ```cmd
   "C:\PostgreSQL\16\bin\psql.exe" -U ofs_app -h localhost -d ofs_db -c "SELECT username FROM users LIMIT 1;"
   ```

2. Se não há users, recarrega seed:
   ```cmd
   cd ofs-feedback
   setup_primeira_vez.bat
   ```

---

## ❌ Firewall bloqueia acesso pela rede local

### Solução:
```cmd
cd ofs-feedback
configurar_rede.bat    # Abre portas 3000 e 8000
```

Depois testa em outro PC:
```
http://<IP_DO_HOST>:3000
```

---

## ❌ Tailscale não funciona

### Passos:
1. **No servidor:** Instala Tailscale → https://tailscale.com/download/windows
2. **Faz login** na sua tailnet
3. Roda:
   ```cmd
   cd ofs-feedback
   configurar_rede.bat    # Mostra IP Tailscale e MagicDNS
   ```
4. **Nos clientes:** Instala Tailscale, faz login na mesma tailnet
5. Acessa:
   ```
   http://100.x.y.z:3000          (IP Tailscale)
   http://servidor-ofs:3000       (MagicDNS, se habilitado)
   ```

---

## ❌ npm install falha

### Causa: Node.js não está instalado ou PATH incorreto

**Solução:**
1. Baixa Node.js: https://nodejs.org (versão LTS)
2. Instala e reinicia o PowerShell/CMD
3. Tenta de novo:
   ```cmd
   cd ofs-feedback
   npm install
   npm run build
   ```

---

## ✅ Tudo funcionando? Próximos passos

1. **Instalar autostart:**
   ```cmd
   instalar_autostart.bat
   ```

2. **Criar atalho na desktop:**
   ```cmd
   criar_atalho.bat
   ```

3. **Configurar rede:**
   ```cmd
   configurar_rede.bat
   ```

4. **Fazer primeiro login:**
   - Abrir http://localhost:3000
   - User: `admin`
   - Senha: `Admin@123`
   - Criar novo usuário via admin → Cadastrar Usuário

---

## 📞 Debug: Ver logs em tempo real

**Backend (FastAPI):**
- Janela de console do `iniciar.bat`
- Ou rodar manual:
  ```cmd
  cd ofs-feedback\backend
  python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level debug
  ```

**Frontend (Vite):**
- Abrir DevTools do navegador (F12) → Console

**PostgreSQL:**
- `type %LOCALAPPDATA%\pglogs_ofs\pg.log`

**Windows Event Viewer:**
- Event Viewer → Windows Logs → System (procura por erros do PostgreSQL)

---

Problema não resolvido? Verifica:
1. Qual é a **mensagem de erro exata**?
2. **Qual script** você rodou?
3. **Qual porta** está com problema?
4. Roda `netstat -ano | findstr ":3000 :8000 :5432"` e copia o resultado
