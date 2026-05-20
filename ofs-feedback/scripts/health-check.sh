#!/bin/bash
# ================================================================
# Sistema OFC/OFS - Security Dynamics
# Script de Verificacao de Saude do Ambiente
# ================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local label="$1"; shift
    if "$@" > /dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${NC}    $label"
        ((PASS++))
    else
        echo -e "  ${RED}[FAIL]${NC}  $label"
        ((FAIL++))
    fi
}

echo "============================================="
echo "  HEALTH CHECK - Sistema OFC/OFS"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================="
echo ""

# 1. Docker
echo "--- Docker ---"
check "docker daemon" docker info

# 2. Containers
echo ""
echo "--- Containers ---"
check "nginx running" docker compose ps -q nginx
check "backend running" docker compose ps -q backend
check "db running" docker compose ps -q db

# 3. PostgreSQL
echo ""
echo "--- PostgreSQL ---"
check "pg_isready" docker compose exec -T db pg_isready -U ofs_app

# 4. Backend API
echo ""
echo "--- Backend API ---"
HEALTH=$(docker compose exec -T backend curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/health 2>/dev/null || echo "000")
if [ "$HEALTH" = "200" ]; then
    BODY=$(docker compose exec -T backend curl -s http://localhost:8000/api/health 2>/dev/null || echo '{}')
    echo -e "  ${GREEN}[OK]${NC}    GET /api/health → HTTP $HEALTH"
    echo "          Response: $BODY"
    ((PASS++))
else
    echo -e "  ${RED}[FAIL]${NC}  GET /api/health → HTTP $HEALTH"
    ((FAIL++))
fi

# 5. Nginx proxy
echo ""
echo "--- Nginx Proxy ---"
PROXY_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health 2>/dev/null || echo "000")
if [ "$PROXY_CODE" = "200" ] || [ "$PROXY_CODE" = "401" ] || [ "$PROXY_CODE" = "302" ]; then
    echo -e "  ${GREEN}[OK]${NC}    http://localhost/api/health → HTTP $PROXY_CODE"
    ((PASS++))
else
    echo -e "  ${RED}[FAIL]${NC}  http://localhost/api/health → HTTP $PROXY_CODE"
    ((FAIL++))
fi

# 6. Frontend
echo ""
echo "--- Frontend ---"
INDEX_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$INDEX_CODE" = "200" ] || [ "$INDEX_CODE" = "302" ]; then
    echo -e "  ${GREEN}[OK]${NC}    http://localhost/ → HTTP $INDEX_CODE"
    ((PASS++))
else
    echo -e "  ${RED}[FAIL]${NC}  http://localhost/ → HTTP $INDEX_CODE"
    ((FAIL++))
fi

echo ""
echo "============================================="
echo -e "  Resultado: ${GREEN}$PASS passaram${NC} / ${RED}$FAIL falharam${NC}"
echo "============================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
