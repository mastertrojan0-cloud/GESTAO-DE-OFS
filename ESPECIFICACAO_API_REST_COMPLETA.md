# ESPECIFICACAO COMPLETA DA API REST — Sistema OFS/OFS

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versao:** MVP 1.0  
**Stack:** FastAPI + SQLAlchemy 2.0 async + PostgreSQL 16  
**Autenticacao:** JWT HS256 (Access Token 15min + Refresh Token 7d)  
**Perfis:** Observador | Supervisor | Gestor | Admin  
**Data:** 13/05/2026

---

## PADRAO DE RESPOSTA

### Sucesso (200/201)
```json
{
  "success": true,
  "data": { ... }
}
```

### Sucesso com Paginacao
```json
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "page_size": 25,
    "total": 47,
    "total_pages": 2
  }
}
```

### Erro
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Descricao do erro",
    "details": [
      { "field": "nome_observado", "error": "Deve ter no minimo 3 caracteres" }
    ]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

### Codigos de Erro
| Code | HTTP | Descricao |
|------|------|-----------|
| `VALIDATION_ERROR` | 422 | Payload invalido (Pydantic) |
| `UNAUTHORIZED` | 401 | Token ausente, invalido ou expirado |
| `FORBIDDEN` | 403 | Perfil sem permissao para o recurso |
| `NOT_FOUND` | 404 | Recurso nao encontrado |
| `CONFLICT` | 409 | Conflito (ex: optimistic lock, ja cancelado) |
| `BUSINESS_RULE` | 422 | Violacao de regra de negocio |
| `LOCKOUT` | 423 | Usuario bloqueado por tentativas |
| `INTERNAL_ERROR` | 500 | Erro interno do servidor |

---

## MODULO 1: AUTH (3 endpoints)

### 1.1 POST /api/auth/login
**Perfil minimo:** Publico (sem autenticacao)

**Request Body:**
```json
{
  "username": "joao.silva",
  "password": "Senha@123"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 900,
    "user": {
      "id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
      "username": "joao.silva",
      "full_name": "Joao Silva",
      "email": "joao.silva@securitydynamics.com.br",
      "role": "supervisor",
      "company_id": 1,
      "company_name": "Security Dynamics"
    }
  }
}
```

**Error 401 (credenciais invalidas):**
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Credenciais invalidas",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 403 (usuario inativo):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Usuario inativo. Contate o administrador.",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 423 (bloqueio por tentativas):**
```json
{
  "success": false,
  "error": {
    "code": "LOCKOUT",
    "message": "Usuario bloqueado ate 13/05/2026 15:00. Foram excedidas 5 tentativas de login.",
    "details": { "locked_until": "2026-05-13T15:00:00-03:00" }
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 1.2 POST /api/auth/logout
**Perfil minimo:** Autenticado (todos)

**Request Body:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "message": "Logout realizado com sucesso"
  }
}
```

**Error 401:**
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Token de acesso ausente ou invalido",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 1.3 GET /api/auth/me
**Perfil minimo:** Autenticado (todos)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "username": "joao.silva",
    "full_name": "Joao Silva",
    "email": "joao.silva@securitydynamics.com.br",
    "role": "supervisor",
    "company_id": 1,
    "company_name": "Security Dynamics",
    "is_active": true,
    "last_login": "2026-05-13T14:30:05-03:00",
    "password_expires_at": "2026-08-11T00:00:00-03:00",
    "created_at": "2025-01-15T08:00:00-03:00"
  }
}
```

**Error 401:**
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Token expirado. Realize login novamente.",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## MODULO 2: USERS (6 endpoints)

### 2.1 GET /api/users
**Perfil minimo:** Gestor (escopo: sua empresa), Admin (todos)

**Query Params:**
| Param | Tipo | Default | Descricao |
|-------|------|---------|-----------|
| `page` | int | 1 | Numero da pagina |
| `page_size` | int | 25 | Itens por pagina (max 100) |
| `role` | string | — | Filtrar por perfil: `observador`, `supervisor`, `gestor`, `admin` |
| `is_active` | bool | — | `true` ou `false` |
| `company_id` | int | — | Filtrar por empresa (Admin only) |

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
      "username": "joao.silva",
      "full_name": "Joao Silva",
      "email": "joao.silva@securitydynamics.com.br",
      "role": "supervisor",
      "company_id": 1,
      "company_name": "Security Dynamics",
      "is_active": true,
      "last_login": "2026-05-13T14:30:05-03:00",
      "created_at": "2025-01-15T08:00:00-03:00"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 25,
    "total": 47,
    "total_pages": 2
  }
}
```

**Error 403 (Observador/Supervisor tentando acessar):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Requer perfil: Gestor, Admin",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 2.2 GET /api/users/{id}
**Perfil minimo:** Gestor (escopo: sua empresa), Admin (todos)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "username": "joao.silva",
    "full_name": "Joao Silva",
    "email": "joao.silva@securitydynamics.com.br",
    "role": "supervisor",
    "company_id": 1,
    "company_name": "Security Dynamics",
    "is_active": true,
    "last_login": "2026-05-13T14:30:05-03:00",
    "login_attempts": 0,
    "password_expires_at": "2026-08-11T00:00:00-03:00",
    "created_at": "2025-01-15T08:00:00-03:00",
    "updated_at": "2026-05-10T16:20:00-03:00"
  }
}
```

**Error 404:**
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Usuario nao encontrado",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 403 (Gestor de outra empresa tentando acessar):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Voce so pode gerenciar usuarios da sua empresa",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 2.3 POST /api/users
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "username": "maria.santos",
  "password": "Senha@456",
  "full_name": "Maria Santos",
  "email": "maria.santos@securitydynamics.com.br",
  "role": "observador",
  "company_id": 1
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": "a7b8c9d0-e1f2-3456-7890-abcdef123456",
    "username": "maria.santos",
    "full_name": "Maria Santos",
    "email": "maria.santos@securitydynamics.com.br",
    "role": "observador",
    "company_id": 1,
    "is_active": true,
    "password_expires_at": "2026-08-11T00:00:00-03:00",
    "created_at": "2026-05-13T14:30:05-03:00"
  }
}
```

**Error 422 (login ja existe):**
```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "Ja existe um usuario com este login",
    "details": [{ "field": "username", "error": "unique constraint violation" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 422 (senha fraca):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Senha nao atende aos requisitos de seguranca",
    "details": [
      { "field": "password", "error": "Minimo 12 caracteres" },
      { "field": "password", "error": "Pelo menos 1 caractere especial" }
    ]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 2.4 PUT /api/users/{id}
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "full_name": "Maria Santos Silva",
  "email": "maria.silva@securitydynamics.com.br",
  "role": "supervisor",
  "company_id": 2
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "a7b8c9d0-e1f2-3456-7890-abcdef123456",
    "username": "maria.santos",
    "full_name": "Maria Santos Silva",
    "email": "maria.silva@securitydynamics.com.br",
    "role": "supervisor",
    "company_id": 2,
    "company_name": "ERA",
    "is_active": true,
    "updated_at": "2026-05-13T14:35:00-03:00"
  }
}
```

**Error 409 (tentando alterar o proprio perfil):**
```json
{
  "success": false,
  "error": {
    "code": "BUSINESS_RULE",
    "message": "Nao e permitido alterar o proprio perfil",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 2.5 PATCH /api/users/{id}/status
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "is_active": false
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "a7b8c9d0-e1f2-3456-7890-abcdef123456",
    "username": "maria.santos",
    "is_active": false,
    "message": "Usuario desativado com sucesso"
  }
}
```

**Error 409 (tentando desativar a si mesmo):**
```json
{
  "success": false,
  "error": {
    "code": "BUSINESS_RULE",
    "message": "Nao e permitido desativar o proprio usuario",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 2.6 PATCH /api/users/{id}/password
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "new_password": "NovaSenha@789"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "message": "Senha alterada com sucesso",
    "password_expires_at": "2026-08-11T00:00:00-03:00"
  }
}
```

**Error 422 (senha reutilizada):**
```json
{
  "success": false,
  "error": {
    "code": "BUSINESS_RULE",
    "message": "Esta senha ja foi utilizada anteriormente. Escolha uma nova senha.",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## MODULO 3: COMPANIES (5 endpoints)

### 3.1 GET /api/companies
**Perfil minimo:** Autenticado (todos). Admin ve inativas tambem.

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Security Dynamics",
      "is_custom": false,
      "is_active": true,
      "created_at": "2025-01-01T00:00:00-03:00"
    },
    {
      "id": 2,
      "name": "ERA",
      "is_custom": false,
      "is_active": true,
      "created_at": "2025-01-01T00:00:00-03:00"
    }
  ]
}
```

---

### 3.2 GET /api/companies/{id}
**Perfil minimo:** Autenticado (todos)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Security Dynamics",
    "is_custom": false,
    "is_active": true,
    "created_at": "2025-01-01T00:00:00-03:00",
    "updated_at": "2025-06-15T10:00:00-03:00",
    "contracts_count": 3,
    "active_users_count": 45
  }
}
```

**Error 404:**
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Empresa nao encontrada",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 3.3 POST /api/companies
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "name": "Transportadora Nova Ltda",
  "is_custom": true
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": 16,
    "name": "Transportadora Nova Ltda",
    "is_custom": true,
    "is_active": true,
    "created_at": "2026-05-13T14:30:05-03:00"
  }
}
```

**Error 422 (nome duplicado):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Ja existe uma empresa cadastrada com este nome",
    "details": [{ "field": "name", "error": "Nome de empresa ja existe" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 3.4 PUT /api/companies/{id}
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "name": "Transportadora Nova Atualizada Ltda"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 16,
    "name": "Transportadora Nova Atualizada Ltda",
    "is_custom": true,
    "is_active": true,
    "updated_at": "2026-05-13T14:35:00-03:00"
  }
}
```

---

### 3.5 PATCH /api/companies/{id}/status
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "is_active": false
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 16,
    "name": "Transportadora Nova Atualizada Ltda",
    "is_active": false,
    "message": "Empresa desativada com sucesso"
  }
}
```

**Error 422 (empresa com usuarios ativos):**
```json
{
  "success": false,
  "error": {
    "code": "BUSINESS_RULE",
    "message": "Nao e possivel desativar empresa com usuarios ativos vinculados",
    "details": [{ "active_users": 12 }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## MODULO 4: CONTRACTS (5 endpoints)

### 4.1 GET /api/contracts
**Perfil minimo:** Autenticado (todos)  
**Query Params:** `?is_active=true` (opcional)

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Operacao Security Dynamics",
      "description": "Contrato principal de operacoes da Security Dynamics",
      "is_active": true,
      "created_at": "2025-01-01T00:00:00-03:00"
    }
  ]
}
```

---

### 4.2 GET /api/contracts/{id}
**Perfil minimo:** Autenticado (todos)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Operacao Security Dynamics",
    "description": "Contrato principal de operacoes da Security Dynamics",
    "is_active": true,
    "users_count": 45,
    "targets_count": 20,
    "ofc_records_count": 1523,
    "created_at": "2025-01-01T00:00:00-03:00",
    "updated_at": "2026-05-10T10:00:00-03:00"
  }
}
```

**Error 404:**
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Contrato nao encontrado",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 4.3 POST /api/contracts
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "name": "Operacao Porto de Santos",
  "description": "Contrato de operacoes portuarias no terminal de Santos"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Operacao Porto de Santos",
    "description": "Contrato de operacoes portuarias no terminal de Santos",
    "is_active": true,
    "created_at": "2026-05-13T14:30:05-03:00"
  }
}
```

**Error 422 (nome vazio):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dados invalidos",
    "details": [{ "field": "name", "error": "Nome do contrato e obrigatorio" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 4.4 PUT /api/contracts/{id}
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "name": "Operacao Porto de Santos - Terminal 2",
  "description": "Contrato de operacoes atualizado — escopo ampliado para Terminal 2"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Operacao Porto de Santos - Terminal 2",
    "description": "Contrato de operacoes atualizado — escopo ampliado para Terminal 2",
    "is_active": true,
    "updated_at": "2026-05-13T14:35:00-03:00"
  }
}
```

---

### 4.5 PATCH /api/contracts/{id}/status
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "is_active": false
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 3,
    "name": "Operacao Porto de Santos - Terminal 2",
    "is_active": false,
    "message": "Contrato desativado com sucesso"
  }
}
```

**Error 422 (contrato com metas vigentes):**
```json
{
  "success": false,
  "error": {
    "code": "BUSINESS_RULE",
    "message": "Nao e possivel desativar contrato com metas vigentes. Remova as metas primeiro.",
    "details": [{ "active_targets": 5 }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## MODULO 5: TARGETS (4 endpoints)

### 5.1 GET /api/targets
**Perfil minimo:** Supervisor (escopo: sua empresa), Gestor+ (todos)  
**Query Params:** `?company_id=1&contract_id=1&ano=2026&semana=20&is_active=true`

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "company_id": 1,
      "company_name": "Security Dynamics",
      "contract_id": 1,
      "contract_name": "Operacao Security Dynamics",
      "week_start": "2026-05-11",
      "active_people": 150,
      "weekly_target": 5,
      "meta_ofc_programada": 750,
      "active_users": 10,
      "is_active": true,
      "created_at": "2026-01-01T00:00:00-03:00",
      "updated_at": "2026-05-10T08:00:00-03:00"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 25,
    "total": 20,
    "total_pages": 1
  }
}
```

---

### 5.2 GET /api/targets/{id}
**Perfil minimo:** Supervisor (escopo: sua empresa), Gestor+ (todos)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "company_id": 1,
    "company_name": "Security Dynamics",
    "contract_id": 1,
    "contract_name": "Operacao Security Dynamics",
    "week_start": "2026-05-11",
    "active_people": 150,
    "weekly_target": 5,
    "meta_ofc_programada": 750,
    "active_users": 10,
    "is_active": true,
    "created_by": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "created_by_name": "Admin Sistema",
    "created_at": "2026-01-01T00:00:00-03:00",
    "updated_at": "2026-05-10T08:00:00-03:00"
  }
}
```

---

### 5.3 POST /api/targets
**Perfil minimo:** Gestor (sua empresa), Admin (todos)

**Request Body:**
```json
{
  "company_id": 1,
  "contract_id": 1,
  "week_start": "2026-05-18",
  "active_people": 160,
  "weekly_target": 5,
  "active_users": 12
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": 21,
    "company_id": 1,
    "company_name": "Security Dynamics",
    "contract_id": 1,
    "contract_name": "Operacao Security Dynamics",
    "week_start": "2026-05-18",
    "active_people": 160,
    "weekly_target": 5,
    "meta_ofc_programada": 800,
    "active_users": 12,
    "is_active": true,
    "created_at": "2026-05-13T14:30:05-03:00"
  }
}
```

**Error 409 (UPSERT — ja existe meta para esta semana):**
```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "Ja existe uma meta cadastrada para esta empresa, contrato e semana",
    "details": [{ "existing_target_id": 15 }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 422 (validacao):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dados invalidos",
    "details": [
      { "field": "active_people", "error": "Deve ser maior ou igual a zero" },
      { "field": "weekly_target", "error": "Deve ser no minimo 1" }
    ]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 5.4 PUT /api/targets/{id}
**Perfil minimo:** Gestor (sua empresa), Admin (todos)

**Request Body:**
```json
{
  "active_people": 170,
  "weekly_target": 6,
  "active_users": 14
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 21,
    "company_id": 1,
    "company_name": "Security Dynamics",
    "contract_id": 1,
    "contract_name": "Operacao Security Dynamics",
    "week_start": "2026-05-18",
    "active_people": 170,
    "weekly_target": 6,
    "meta_ofc_programada": 1020,
    "active_users": 14,
    "is_active": true,
    "updated_at": "2026-05-13T14:35:00-03:00"
  }
}
```

---

## MODULO 6: OFS RECORDS (6 endpoints)

### 6.1 POST /api/OFS-records
**Perfil minimo:** Observador (todos podem criar)

**Request Body:**
```json
{
  "data_registro": "2026-05-13",
  "empresa_observada_id": 1,
  "empresa_observada_outros": null,
  "nome_observado": "Carlos Silva",
  "atividade_observada": "Operacao de empilhadeira no armazem B",
  "local_observado": "Armazem B",
  "contrato_id": 1,
  "turno": "Diurno",
  "tipo_observacao": "Positivo/Seguro",
  "comportamento_observado": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota e colete. Verificou area antes de iniciar operacao.",
  "observacao_complementar": "Operador demonstrou atencao redobrada aos procedimentos de seguranca"
}
```

**Request Body (Empresa "Outros"):**
```json
{
  "data_registro": "2026-05-13",
  "empresa_observada_id": null,
  "empresa_observada_outros": "Transportadora Rapida Ltda",
  "nome_observado": "Maria Aparecida",
  "atividade_observada": "Carregamento de conteineres",
  "local_observado": "Patio de Carga",
  "contrato_id": 1,
  "turno": "Noturno",
  "tipo_observacao": "Negativo/Inseguro",
  "comportamento_observado": "Ausencia de cinto de seguranca durante operacao em altura",
  "observacao_complementar": "Foi orientada imediatamente e retomou com o EPI"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": "OFS-2026-20-0001",
    "data_registro": "2026-05-13",
    "hora_registro": "14:30:00",
    "semana": 20,
    "mes": 5,
    "ano": 2026,
    "usuario_id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "usuario_nome_snapshot": "Carlos Henrique Oliveira",
    "usuario_login_snapshot": "carlos.oliveira",
    "usuario_email_snapshot": "carlos.oliveira@securitydynamics.com.br",
    "usuario_perfil_snapshot": "supervisor",
    "empresa_usuario_snapshot": "Security Dynamics",
    "contrato_id": 1,
    "empresa_observada_id": 1,
    "empresa_observada_outros": null,
    "nome_observado": "Carlos Silva",
    "atividade_observada": "Operacao de empilhadeira no armazem B",
    "local_observado": "Armazem B",
    "turno": "Diurno",
    "tipo_observacao": "Positivo/Seguro",
    "comportamento_observado": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota e colete. Verificou area antes de iniciar operacao.",
    "observacao_complementar": "Operador demonstrou atencao redobrada aos procedimentos de seguranca",
    "status_registro": "Gerado",
    "is_deleted": false,
    "edit_count": 0,
    "criado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "criado_em": "2026-05-13T14:30:05-03:00",
    "updated_at": "2026-05-13T14:30:05-03:00"
  }
}
```

**Error 422 (validacao — empresa_observada_outros obrigatorio):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Campo 'empresa_observada_outros' e obrigatorio quando nenhuma empresa da lista e selecionada",
    "details": [{ "field": "empresa_observada_outros", "error": "Campo obrigatorio para 'Outros'" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 422 (validacao — data futura):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dados invalidos",
    "details": [{ "field": "data_registro", "error": "Data de registro nao pode ser futura" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 6.2 GET /api/OFS-records
**Perfil minimo:** Observador (com escopo: apenas seus registros)  
**Supervisor:** escopo = sua empresa  
**Gestor/Admin:** todos os registros

**Query Params:**
| Param | Tipo | Default | Descricao |
|-------|------|---------|-----------|
| `codigo` | int | — | Numero sequencial do OFS (ex: 1523) |
| `data_inicio` | date | — | Data inicial do periodo (YYYY-MM-DD) |
| `data_fim` | date | — | Data final do periodo (YYYY-MM-DD) |
| `semana` | int | — | Numero da semana (1-53) |
| `mes` | int | — | Mes (1-12) |
| `ano` | int | — | Ano (ex: 2026) |
| `usuario_id` | UUID | — | Usuario gerador do registro |
| `empresa_observada_id` | int | — | Empresa observada |
| `contrato_id` | int | — | Contrato |
| `turno` | string | — | Diurno, Noturno, Administrativo, Turno 1, Turno 2, Turno 3 |
| `tipo_observacao` | string | — | Positivo/Seguro, Negativo/Inseguro |
| `status_registro` | string | — | Gerado, Editado, Cancelado |
| `busca` | string | — | Busca textual (full-text search em portugues) |
| `page` | int | 1 | Numero da pagina |
| `page_size` | int | 25 | Itens por pagina (max 100) |
| `order_by` | string | criado_em | Campo de ordenacao: `codigo`, `data_registro`, `criado_em`, `turno`, `tipo_observacao` |
| `order_dir` | string | desc | Direcao: `asc` ou `desc` |

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "codigo": "OFS-2026-20-0001",
      "data_registro": "2026-05-13",
      "hora_registro": "14:30:00",
      "nome_observado": "Carlos Silva",
      "empresa_observada_id": 1,
      "empresa_nome": "Security Dynamics",
      "contrato_id": 1,
      "contrato_nome": "Operacao Security Dynamics",
      "turno": "Diurno",
      "tipo_observacao": "Positivo/Seguro",
      "comportamento_observado": "Uso correto de todos os EPIs obrigatorios...",
      "status_registro": "Gerado",
      "usuario_nome_snapshot": "Carlos Henrique Oliveira",
      "edit_count": 0,
      "criado_em": "2026-05-13T14:30:05-03:00",
      "updated_at": "2026-05-13T14:30:05-03:00"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 25,
    "total": 47,
    "total_pages": 2
  }
}
```

---

### 6.3 GET /api/OFS-records/{id}
**Perfil minimo:** Observador (escopo: apenas seus), Supervisor (escopo: sua empresa), Gestor/Admin (todos)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": "OFS-2026-20-0001",
    "data_registro": "2026-05-13",
    "hora_registro": "14:30:00",
    "semana": 20,
    "mes": 5,
    "ano": 2026,
    "usuario_id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "usuario_nome_snapshot": "Carlos Henrique Oliveira",
    "usuario_login_snapshot": "carlos.oliveira",
    "usuario_email_snapshot": "carlos.oliveira@securitydynamics.com.br",
    "usuario_perfil_snapshot": "supervisor",
    "empresa_usuario_snapshot": "Security Dynamics",
    "contrato_id": 1,
    "contrato_nome": "Operacao Security Dynamics",
    "empresa_observada_id": 1,
    "empresa_observada_nome": "Security Dynamics",
    "empresa_observada_outros": null,
    "nome_observado": "Carlos Silva",
    "atividade_observada": "Operacao de empilhadeira no armazem B",
    "local_observado": "Armazem B",
    "turno": "Diurno",
    "tipo_observacao": "Positivo/Seguro",
    "comportamento_observado": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota e colete. Verificou area antes de iniciar operacao.",
    "observacao_complementar": "Operador demonstrou atencao redobrada aos procedimentos de seguranca",
    "status_registro": "Editado",
    "is_deleted": false,
    "edit_count": 2,
    "criado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "criado_em": "2026-05-13T14:30:05-03:00",
    "editado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "editado_em": "2026-05-13T16:45:00-03:00",
    "edicoes": [
      {
        "id": 1,
        "campo_alterado": "comportamento_observado",
        "valor_anterior": "Uso correto de todos os EPIs obrigatorios...",
        "valor_novo": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota, colete e protetor auricular...",
        "editado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
        "editado_por_nome": "Carlos Henrique Oliveira",
        "editado_em": "2026-05-13T16:45:00-03:00"
      },
      {
        "id": 2,
        "campo_alterado": "observacao_complementar",
        "valor_anterior": "Operador demonstrou atencao redobrada...",
        "valor_novo": "Operador demonstrou dominio completo dos protocolos de seguranca.",
        "editado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
        "editado_por_nome": "Carlos Henrique Oliveira",
        "editado_em": "2026-05-13T16:45:00-03:00"
      }
    ],
    "updated_at": "2026-05-13T16:45:00-03:00"
  }
}
```

**Error 403 (Observador tentando ver OFS de outro usuario):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Voce nao tem permissao para visualizar este registro",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 6.4 PUT /api/OFS-records/{id}
**Perfil minimo:** Observador (apenas seus, janela 24h), Supervisor (sua empresa, janela 48h), Gestor/Admin (todos, sem limite)

**Request Body:**
```json
{
  "comportamento_observado": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota, colete e protetor auricular. Verificou area antes de iniciar operacao.",
  "observacao_complementar": "Operador demonstrou dominio completo dos protocolos de seguranca.",
  "turno": "Noturno",
  "updated_at": "2026-05-13T14:30:05-03:00"
}
```

> **IMPORTANTE:** `updated_at` e obrigatorio para optimistic locking. O valor deve ser o `updated_at` do registro recebido no GET anterior.

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": "OFS-2026-20-0001",
    "status_registro": "Editado",
    "edit_count": 3,
    "editado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "editado_em": "2026-05-13T17:00:00-03:00",
    "edicoes_realizadas": [
      {
        "campo": "comportamento_observado",
        "valor_anterior": "Uso correto de todos os EPIs obrigatorios...",
        "valor_novo": "Uso correto de todos os EPIs obrigatorios: capacete, luva, bota, colete e protetor auricular..."
      },
      {
        "campo": "observacao_complementar",
        "valor_anterior": "Operador demonstrou atencao redobrada...",
        "valor_novo": "Operador demonstrou dominio completo dos protocolos de seguranca."
      },
      {
        "campo": "turno",
        "valor_anterior": "Diurno",
        "valor_novo": "Noturno"
      }
    ],
    "updated_at": "2026-05-13T17:00:00-03:00"
  }
}
```

**Error 409 (optimistic lock — outro usuario editou antes):**
```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "Registro foi modificado por outro usuario. Recarregue e tente novamente.",
    "details": {
      "server_updated_at": "2026-05-13T16:45:00-03:00",
      "client_updated_at": "2026-05-13T14:30:05-03:00"
    }
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 403 (janela de edicao expirada):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Janela de edicao expirada (24h). Contate um Gestor ou Admin.",
    "details": { "role": "observador", "window_hours": 24, "elapsed_hours": 26 }
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 403 (Supervisor tentando editar OFS de outra empresa):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Voce so pode editar registros da sua empresa/contrato",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 6.5 PATCH /api/OFS-records/{id}/cancel
**Perfil minimo:** Gestor (todos), Admin (todos)

> **IMPORTANTE:** O cancelamento e SOFT DELETE. O registro nunca e excluido fisicamente (trigger PostgreSQL impede DELETE).

**Request Body:**
```json
{
  "motivo_cancelamento": "Registro duplicado — OFS ja havia sido criada pelo usuario Pedro Costa para o mesmo colaborador no mesmo horario"
}
```

> `motivo_cancelamento`: obrigatorio, minimo 10 caracteres.

**Response 200:**
```json
{
  "success": true,
  "data": {
    "message": "Registro cancelado com sucesso.",
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": "OFS-2026-20-0001",
    "status_registro": "Cancelado",
    "is_deleted": true,
    "cancelado_por": "g9h8i7j6-k5l4-3210-mnop-qrstuv987654",
    "cancelado_em": "2026-05-13T17:00:00-03:00",
    "motivo_cancelamento": "Registro duplicado — OFS ja havia sido criada..."
  }
}
```

**Error 403 (Observador ou Supervisor tentando cancelar):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Requer perfil: Gestor, Admin. Apenas estes perfis podem cancelar registros.",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 409 (registro ja cancelado):**
```json
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "Registro ja esta cancelado",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

**Error 422 (motivo muito curto):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Motivo do cancelamento deve ter no minimo 10 caracteres",
    "details": [{ "field": "motivo_cancelamento", "error": "min_length: 10" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 6.6 GET /api/OFS-records/{id}/pdf
**Perfil minimo:** Observador (apenas seus), Supervisor (sua empresa), Gestor/Admin (todos)

**Response 200:** `Content-Type: application/pdf`  
**Headers:** `Content-Disposition: attachment; filename="OFC_INDIVIDUAL_OFC-2026-20-0001_20260513.pdf"`

**Error 403:**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Voce nao tem permissao para gerar PDF deste registro",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## MODULO 7: METRICS (7 endpoints)

### 7.1 GET /api/metrics/week
**Perfil minimo:** Supervisor (escopo: sua empresa), Gestor/Admin (todos)  
**Query Params:** `?ano=2026&semana=20&contrato_id=1`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "periodo": {
      "ano": 2026,
      "semana": 20,
      "data_inicio": "2026-05-11",
      "data_fim": "2026-05-17"
    },
    "contrato": {
      "id": 1,
      "nome": "Operacao Security Dynamics"
    },
    "meta": {
      "cadastrada": true,
      "target_id": 1,
      "pessoas_ativas": 150,
      "meta_ofc_por_pessoa": 5,
      "ofc_programadas": 750,
      "usuarios_ativos_esperados": 10
    },
    "indicadores": {
      "pessoas_ativas": 150,
      "ofc_programadas": 750,
      "ofc_realizadas": 645,
      "aderencia_percentual": 86.0,
      "positivas": 520,
      "negativas": 125,
      "percentual_seguro": 80.6,
      "percentual_desvio": 19.4,
      "usuarios_ativos": 9,
      "media_ofc_por_usuario": 71.7
    },
    "status": "ATENCAO",
    "status_cor": "#EAB308",
    "status_descricao": "Aderencia entre 80% e 99% — atencao necessaria",
    "top_comportamentos_seguros": [
      { "comportamento": "Uso correto de EPI", "total": 45 },
      { "comportamento": "Sinalizacao adequada de area", "total": 38 },
      { "comportamento": "Comunicacao efetiva com equipe", "total": 32 }
    ],
    "top_comportamentos_desvios": [
      { "comportamento": "Falta de sinalizacao em area de risco", "total": 12 },
      { "comportamento": "Ausencia de cinto de seguranca", "total": 9 },
      { "comportamento": "Nao utilizacao de luva de protecao", "total": 7 }
    ],
    "resumo_por_turno": [
      { "turno": "Diurno", "total": 280, "positivas": 230, "negativas": 50 },
      { "turno": "Noturno", "total": 210, "positivas": 170, "negativas": 40 },
      { "turno": "Administrativo", "total": 100, "positivas": 80, "negativas": 20 },
      { "turno": "Turno 1", "total": 55, "positivas": 40, "negativas": 15 }
    ],
    "gerado_em": "2026-05-13T15:30:00-03:00",
    "gerado_por": "Carlos Henrique Oliveira"
  }
}
```

**Error 403 (Observador tentando acessar):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Requer perfil: Supervisor, Gestor, Admin",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

### 7.2 GET /api/metrics/month
**Perfil minimo:** Supervisor (escopo: sua empresa), Gestor/Admin (todos)  
**Query Params:** `?ano=2026&mes=5&contrato_id=1`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "periodo": {
      "ano": 2026,
      "mes": 5,
      "mes_nome": "Maio",
      "data_inicio": "2026-05-01",
      "data_fim": "2026-05-31"
    },
    "contrato": {
      "id": 1,
      "nome": "Operacao Security Dynamics"
    },
    "resumo_mensal": {
      "total_ofc_programadas": 3100,
      "total_ofc_realizadas": 2735,
      "aderencia_percentual": 88.2,
      "total_positivas": 2200,
      "total_negativas": 535,
      "percentual_seguro_medio": 80.4,
      "percentual_desvio_medio": 19.6,
      "media_ofc_semanal": 683.8,
      "usuarios_ativos_medio": 9.5,
      "media_ofc_por_usuario": 72.0,
      "melhor_semana": { "semana": 17, "aderencia": 101.3, "status": "OK" },
      "pior_semana": { "semana": 20, "aderencia": 86.0, "status": "ATENCAO" }
    },
    "status": "ATENCAO",
    "status_cor": "#EAB308",
    "evolucao_semanal": [
      {
        "semana": 17, "data_inicio": "2026-04-20",
        "programadas": 800, "realizadas": 810,
        "aderencia_percentual": 101.3, "status": "OK"
      },
      {
        "semana": 18, "data_inicio": "2026-04-27",
        "programadas": 750, "realizadas": 690,
        "aderencia_percentual": 92.0, "status": "ATENCAO"
      },
      {
        "semana": 19, "data_inicio": "2026-05-04",
        "programadas": 750, "realizadas": 710,
        "aderencia_percentual": 94.7, "status": "ATENCAO"
      },
      {
        "semana": 20, "data_inicio": "2026-05-11",
        "programadas": 750, "realizadas": 645,
        "aderencia_percentual": 86.0, "status": "ATENCAO"
      }
    ],
    "gerado_em": "2026-05-13T15:30:00-03:00"
  }
}
```

---

### 7.3 GET /api/metrics/company-ranking
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?ano=2026&semana=20`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "periodo": {
      "ano": 2026,
      "semana": 20
    },
    "ranking": [
      {
        "posicao": 1,
        "empresa_id": 3,
        "empresa_nome": "ERA",
        "ofc_programadas": 500,
        "ofc_realizadas": 510,
        "positivas": 450,
        "negativas": 60,
        "aderencia_percentual": 102.0,
        "percentual_seguro": 88.2,
        "status": "OK",
        "status_cor": "#22C55E"
      },
      {
        "posicao": 2,
        "empresa_id": 1,
        "empresa_nome": "Security Dynamics",
        "ofc_programadas": 750,
        "ofc_realizadas": 645,
        "positivas": 520,
        "negativas": 125,
        "aderencia_percentual": 86.0,
        "percentual_seguro": 80.6,
        "status": "ATENCAO",
        "status_cor": "#EAB308"
      },
      {
        "posicao": 3,
        "empresa_id": 4,
        "empresa_nome": "Polo Norte",
        "ofc_programadas": 250,
        "ofc_realizadas": 196,
        "positivas": 156,
        "negativas": 40,
        "aderencia_percentual": 78.4,
        "percentual_seguro": 79.6,
        "status": "ALERTA",
        "status_cor": "#EF4444"
      }
    ],
    "gerado_em": "2026-05-13T15:30:00-03:00"
  }
}
```

---

### 7.4 GET /api/metrics/user-ranking
**Perfil minimo:** Supervisor (escopo: sua empresa), Gestor/Admin (todos)  
**Query Params:** `?ano=2026&semana=20&contrato_id=1`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "periodo": {
      "ano": 2026,
      "semana": 20
    },
    "contrato_id": 1,
    "ranking": [
      {
        "posicao": 1,
        "usuario_id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
        "usuario_nome": "Carlos Henrique Oliveira",
        "total_ofc": 85,
        "positivas": 70,
        "negativas": 15,
        "media_diaria": 17.0,
        "percentual_seguro": 82.4,
        "ultimo_registro": "2026-05-17T16:30:00-03:00"
      },
      {
        "posicao": 2,
        "usuario_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
        "usuario_nome": "Ana Souza",
        "total_ofc": 72,
        "positivas": 60,
        "negativas": 12,
        "media_diaria": 14.4,
        "percentual_seguro": 83.3,
        "ultimo_registro": "2026-05-17T15:10:00-03:00"
      },
      {
        "posicao": 3,
        "usuario_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
        "usuario_nome": "Rafael Costa",
        "total_ofc": 0,
        "positivas": 0,
        "negativas": 0,
        "media_diaria": 0.0,
        "percentual_seguro": null,
        "ultimo_registro": null,
        "alerta": "Usuario ativo sem registros na semana"
      }
    ],
    "gerado_em": "2026-05-13T15:30:00-03:00"
  }
}
```

---

### 7.5 GET /api/metrics/evolution
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?contrato_id=1&semanas=8` (padrao: 8 semanas)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "contrato_id": 1,
    "contrato_nome": "Operacao Security Dynamics",
    "evolucao": [
      {
        "ano": 2026, "semana": 13,
        "data_inicio": "2026-03-23",
        "programadas": 750, "realizadas": 720,
        "aderencia_percentual": 96.0, "status": "ATENCAO", "status_cor": "#EAB308"
      },
      {
        "ano": 2026, "semana": 14,
        "data_inicio": "2026-03-30",
        "programadas": 750, "realizadas": 755,
        "aderencia_percentual": 100.7, "status": "OK", "status_cor": "#22C55E"
      },
      {
        "ano": 2026, "semana": 15,
        "data_inicio": "2026-04-06",
        "programadas": 800, "realizadas": 810,
        "aderencia_percentual": 101.3, "status": "OK", "status_cor": "#22C55E"
      },
      {
        "ano": 2026, "semana": 16,
        "data_inicio": "2026-04-13",
        "programadas": 800, "realizadas": 700,
        "aderencia_percentual": 87.5, "status": "ATENCAO", "status_cor": "#EAB308"
      },
      {
        "ano": 2026, "semana": 17,
        "data_inicio": "2026-04-20",
        "programadas": 800, "realizadas": 680,
        "aderencia_percentual": 85.0, "status": "ATENCAO", "status_cor": "#EAB308"
      },
      {
        "ano": 2026, "semana": 18,
        "data_inicio": "2026-04-27",
        "programadas": 750, "realizadas": 690,
        "aderencia_percentual": 92.0, "status": "ATENCAO", "status_cor": "#EAB308"
      },
      {
        "ano": 2026, "semana": 19,
        "data_inicio": "2026-05-04",
        "programadas": 750, "realizadas": 710,
        "aderencia_percentual": 94.7, "status": "ATENCAO", "status_cor": "#EAB308"
      },
      {
        "ano": 2026, "semana": 20,
        "data_inicio": "2026-05-11",
        "programadas": 750, "realizadas": 645,
        "aderencia_percentual": 86.0, "status": "ATENCAO", "status_cor": "#EAB308"
      }
    ],
    "tendencia": {
      "direcao": "queda",
      "variacao_percentual": -8.7,
      "periodo_comparacao": "ultimas 4 semanas vs 4 semanas anteriores",
      "media_aderencia_recente": 89.4,
      "media_aderencia_anterior": 97.9
    },
    "gerado_em": "2026-05-13T15:30:00-03:00"
  }
}
```

---

### 7.6 GET /api/metrics/top-behaviors
**Perfil minimo:** Supervisor (escopo: sua empresa), Gestor/Admin (todos)  
**Query Params:** `?ano=2026&semana=20&contrato_id=1&tipo=Positivo/Seguro&limite=10`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "periodo": { "ano": 2026, "semana": 20 },
    "tipo": "Positivo/Seguro",
    "comportamentos": [
      { "posicao": 1, "comportamento": "Uso correto de EPI completo", "ocorrencias": 45, "percentual": 8.7 },
      { "posicao": 2, "comportamento": "Sinalizacao adequada de area", "ocorrencias": 38, "percentual": 7.3 },
      { "posicao": 3, "comportamento": "Comunicacao efetiva com equipe", "ocorrencias": 32, "percentual": 6.2 },
      { "posicao": 4, "comportamento": "Verificacao pre-operacional", "ocorrencias": 28, "percentual": 5.4 },
      { "posicao": 5, "comportamento": "Participacao em DDS", "ocorrencias": 25, "percentual": 4.8 }
    ],
    "total_ocorrencias": 520,
    "gerado_em": "2026-05-13T15:30:00-03:00"
  }
}
```

---

### 7.7 GET /api/metrics/deviations
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?ano=2026&mes=5&contrato_id=1`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "periodo": { "ano": 2026, "mes": 5 },
    "contrato_id": 1,
    "resumo": {
      "total_desvios": 535,
      "percentual_desvio": 19.6,
      "status_desvio": "ALERTA",
      "status_cor": "#EF4444"
    },
    "desvios_por_turno": [
      { "turno": "Diurno", "total": 180, "percentual": 33.6 },
      { "turno": "Noturno", "total": 220, "percentual": 41.1 },
      { "turno": "Administrativo", "total": 85, "percentual": 15.9 },
      { "turno": "Turno 1", "total": 50, "percentual": 9.3 }
    ],
    "desvios_por_local": [
      { "local": "Armazem B", "total": 120, "percentual": 22.4 },
      { "local": "Patio de Manobras", "total": 95, "percentual": 17.8 },
      { "local": "Portaria Principal", "total": 80, "percentual": 15.0 }
    ],
    "top_desvios": [
      { "posicao": 1, "comportamento": "Falta de sinalizacao em area de risco", "ocorrencias": 52 },
      { "posicao": 2, "comportamento": "Ausencia de cinto de seguranca", "ocorrencias": 43 },
      { "posicao": 3, "comportamento": "Nao utilizacao de luva de protecao", "ocorrencias": 38 }
    ],
    "evolucao_desvios": [
      { "semana": 17, "total": 110, "percentual": 13.6 },
      { "semana": 18, "total": 120, "percentual": 17.4 },
      { "semana": 19, "total": 140, "percentual": 19.7 },
      { "semana": 20, "total": 125, "percentual": 19.4 }
    ],
    "gerado_em": "2026-05-13T15:30:00-03:00"
  }
}
```

---

## MODULO 8: REPORTS (5 endpoints)

> Todos os endpoints de relatorio retornam `Content-Type: application/pdf` ou `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` com `Content-Disposition: attachment`.

### 8.1 GET /api/reports/OFS/{id}/pdf
**Perfil minimo:** Observador (apenas seus), Supervisor (sua empresa), Gestor/Admin (todos)

**Response 200:** PDF em A4 retrato (1 pagina para OFS simples, 2+ com historico de edicoes)  
**Filename:** `OFC_INDIVIDUAL_OFC-2026-20-0001_20260513.pdf`

---

### 8.2 GET /api/reports/week/pdf
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?ano=2026&semana=20&contrato_id=1`

**Response 200:** PDF em A4 retrato (2-3 paginas) com:
- Cabecalho corporativo (logo Security Dynamics)
- 10 indicadores em tabela formatada
- Grafico: Programado x Realizado (barras)
- Grafico: Positivo x Negativo (donut)
- Grafico: OFS por Empresa (barras horizontais)
- Grafico: Evolucao Semanal (linha, 8 semanas)
- Tabela Consolidada por empresa/contrato

**Filename:** `METRICAS_SEMANA_2026_20_20260513.pdf`

---

### 8.3 GET /api/reports/month/pdf
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?ano=2026&mes=5&contrato_id=1`

**Response 200:** PDF em A4 retrato (2-3 paginas) com:
- Cabecalho corporativo
- Resumo mensal (total programadas, realizadas, aderencia)
- Tabela de evolucao semanal do mes (4-5 semanas)
- Grafico: Aderencia por Semana (linha)
- Grafico: Positivo x Negativo por Semana (barras empilhadas)
- Grafico: Programado x Realizado por Semana (barras lado a lado)

**Filename:** `METRICAS_MENSAL_2026_05_20260513.pdf`

---

### 8.4 GET /api/reports/week/excel
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?ano=2026&semana=20&contrato_id=1`

**Response 200:** Arquivo `.xlsx` com 3 abas:
- **Resumo:** 10 indicadores com formatacao corporativa
- **Consolidado:** Tabela por empresa (12 colunas) com autofiltro
- **Registros Base:** Detalhe dos OFCs usados no calculo

**Filename:** `METRICAS_SEMANA_2026_20_20260513.xlsx`

---

### 8.5 GET /api/reports/month/excel
**Perfil minimo:** Gestor, Admin  
**Query Params:** `?ano=2026&mes=5&contrato_id=1`

**Response 200:** Arquivo `.xlsx` com 4 abas:
- **Resumo Mensal:** Indicadores consolidados do mes
- **Evolucao Semanal:** Tabela semana a semana
- **Ranking Empresas:** Ranking por aderencia
- **Registros Base:** Detalhe dos OFCs usados

**Filename:** `METRICAS_MENSAL_2026_05_20260513.xlsx`

---

## MODULO 9: AUDIT (1 endpoint)

### 9.1 GET /api/audit-logs
**Perfil minimo:** Admin (exclusivo)  
**Query Params:** `?user_id=&action=&resource=&start_date=&end_date=&severity=&page=1&page_size=50`

| Param | Tipo | Descricao |
|-------|------|-----------|
| `user_id` | UUID | Filtrar por usuario |
| `action` | string | Ex: `OFC_CREATE`, `OFC_UPDATE`, `OFC_CANCEL`, `LOGIN_SUCCESS`, `LOGIN_FAILED` |
| `resource` | string | Ex: `ofc_records`, `users`, `auth` |
| `start_date` | datetime | Data/hora inicio |
| `end_date` | datetime | Data/hora fim |
| `severity` | string | `INFO`, `WARN`, `CRITICAL` |
| `page` | int | Pagina (default 1) |
| `page_size` | int | Itens por pagina (default 50, max 200) |

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": 12345,
      "timestamp": "2026-05-13T14:30:05-03:00",
      "user_id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
      "username": "carlos.oliveira",
      "action": "OFC_CREATE",
      "resource": "ofc_records",
      "resource_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "details": {
        "codigo": "OFS-2026-20-0001",
        "tipo": "Positivo/Seguro",
        "empresa": "Security Dynamics"
      },
      "ip_address": "192.168.1.50",
      "severity": "INFO",
      "created_at": "2026-05-13T14:30:05-03:00"
    },
    {
      "id": 12346,
      "timestamp": "2026-05-13T16:45:00-03:00",
      "user_id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
      "username": "carlos.oliveira",
      "action": "OFC_UPDATE",
      "resource": "ofc_records",
      "resource_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "details": {
        "codigo": "OFS-2026-20-0001",
        "campos_alterados": ["comportamento_observado", "observacao_complementar", "turno"],
        "edit_count": 3
      },
      "ip_address": "192.168.1.50",
      "severity": "WARN",
      "created_at": "2026-05-13T16:45:00-03:00"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 50,
    "total": 1234,
    "total_pages": 25
  }
}
```

**Error 403 (nao-Admin):**
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "Requer perfil: Admin",
    "details": []
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## MODULO 10: SYSTEM (2 endpoints)

### 10.1 GET /api/system-params
**Perfil minimo:** Admin

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "key": "nome_sistema",
      "value": "Sistema OFS/OFS",
      "description": "Nome do sistema exibido na interface"
    },
    {
      "key": "tempo_sessao_minutos",
      "value": "480",
      "description": "Tempo maximo de sessao inativa em minutos"
    }
  ]
}
```

---

### 10.2 PUT /api/system-params/{key}
**Perfil minimo:** Admin

**Request Body:**
```json
{
  "value": "Sistema de Feedback Comportamental OFS/OFS",
  "description": "Nome do sistema exibido na interface e nos relatorios PDF"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "key": "nome_sistema",
    "value": "Sistema de Feedback Comportamental OFS/OFS",
    "description": "Nome do sistema exibido na interface e nos relatorios PDF",
    "updated_at": "2026-05-13T14:30:05-03:00"
  }
}
```

**Error 404 (chave inexistente):**
```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Parametro de sistema nao encontrado",
    "details": [{ "key": "parametro_inexistente" }]
  },
  "timestamp": "2026-05-13T14:30:05-03:00"
}
```

---

## RESUMO DA MATRIZ DE PERMISSOES (RBAC)

| Modulo — Endpoint | Observador | Supervisor | Gestor | Admin |
|---|---:|---:|---:|---:|
| **AUTH** |||||
| POST /api/auth/login | ✅ | ✅ | ✅ | ✅ |
| POST /api/auth/logout | ✅ | ✅ | ✅ | ✅ |
| GET /api/auth/me | ✅ | ✅ | ✅ | ✅ |
| **USERS** |||||
| GET /api/users | ❌ | ❌ | 🔸 sua empresa | ✅ |
| GET /api/users/{id} | ❌ | ❌ | 🔸 sua empresa | ✅ |
| POST /api/users | ❌ | ❌ | ❌ | ✅ |
| PUT /api/users/{id} | ❌ | ❌ | ❌ | ✅ |
| PATCH /api/users/{id}/status | ❌ | ❌ | ❌ | ✅ |
| PATCH /api/users/{id}/password | ❌ | ❌ | ❌ | ✅ |
| **COMPANIES** |||||
| GET /api/companies | ✅ | ✅ | ✅ | ✅ |
| GET /api/companies/{id} | ✅ | ✅ | ✅ | ✅ |
| POST /api/companies | ❌ | ❌ | ❌ | ✅ |
| PUT /api/companies/{id} | ❌ | ❌ | ❌ | ✅ |
| PATCH /api/companies/{id}/status | ❌ | ❌ | ❌ | ✅ |
| **CONTRACTS** |||||
| GET /api/contracts | ✅ | ✅ | ✅ | ✅ |
| GET /api/contracts/{id} | ✅ | ✅ | ✅ | ✅ |
| POST /api/contracts | ❌ | ❌ | ❌ | ✅ |
| PUT /api/contracts/{id} | ❌ | ❌ | ❌ | ✅ |
| PATCH /api/contracts/{id}/status | ❌ | ❌ | ❌ | ✅ |
| **TARGETS** |||||
| GET /api/targets | ❌ | 🔸 sua empresa | ✅ | ✅ |
| GET /api/targets/{id} | ❌ | 🔸 sua empresa | ✅ | ✅ |
| POST /api/targets | ❌ | ❌ | 🔸 sua empresa | ✅ |
| PUT /api/targets/{id} | ❌ | ❌ | 🔸 sua empresa | ✅ |
| **OFS RECORDS** |||||
| POST /api/OFS-records | ✅ | ✅ | ✅ | ✅ |
| GET /api/OFS-records | 🔹 seus | 🔸 sua empresa | ✅ | ✅ |
| GET /api/OFS-records/{id} | 🔹 seu | 🔸 sua empresa | ✅ | ✅ |
| PUT /api/OFS-records/{id} | 🔹⏱ seu, 24h | 🔸⏱ empresa, 48h | ✅ | ✅ |
| PATCH /api/OFS-records/{id}/cancel | ❌ | ❌ | ✅ | ✅ |
| GET /api/OFS-records/{id}/pdf | 🔹 seu | 🔸 sua empresa | ✅ | ✅ |
| **METRICS** |||||
| GET /api/metrics/week | ❌ | 🔸 sua empresa | ✅ | ✅ |
| GET /api/metrics/month | ❌ | 🔸 sua empresa | ✅ | ✅ |
| GET /api/metrics/company-ranking | ❌ | ❌ | ✅ | ✅ |
| GET /api/metrics/user-ranking | ❌ | 🔸 sua empresa | ✅ | ✅ |
| GET /api/metrics/evolution | ❌ | ❌ | ✅ | ✅ |
| GET /api/metrics/top-behaviors | ❌ | 🔸 sua empresa | ✅ | ✅ |
| GET /api/metrics/deviations | ❌ | ❌ | ✅ | ✅ |
| **REPORTS** |||||
| GET /api/reports/OFS/{id}/pdf | 🔹 seu | 🔸 sua empresa | ✅ | ✅ |
| GET /api/reports/week/pdf | ❌ | ❌ | ✅ | ✅ |
| GET /api/reports/month/pdf | ❌ | ❌ | ✅ | ✅ |
| GET /api/reports/week/excel | ❌ | ❌ | ✅ | ✅ |
| GET /api/reports/month/excel | ❌ | ❌ | ✅ | ✅ |
| **AUDIT** |||||
| GET /api/audit-logs | ❌ | ❌ | ❌ | ✅ |
| **SYSTEM** |||||
| GET /api/system-params | ❌ | ❌ | ❌ | ✅ |
| PUT /api/system-params/{key} | ❌ | ❌ | ❌ | ✅ |

**Legenda:**
- ✅ Acesso total (com ou sem escopo)
- 🔹 Escopo: apenas registros proprios (WHERE usuario_id = user.id)
- 🔸 Escopo: apenas registros da empresa (WHERE empresa_id/contrato_id = user.company_id)
- 🔹⏱ Escopo proprio + janela de tempo (24h para Observador)
- 🔸⏱ Escopo empresa + janela de tempo (48h para Supervisor)
- ❌ Sem acesso

---

## HEADERS REQUERIDOS

| Header | Valor | Descricao |
|--------|-------|-----------|
| `Authorization` | `Bearer <access_token>` | Token JWT em todas as rotas protegidas |
| `Content-Type` | `application/json` | Todos os endpoints (zero multipart/upload) |
| `Accept` | `application/json` | Formato de resposta padrao |

---

## VALIDACOES GERAIS DE NEGOCIO

| Regra | Campo | Validacao |
|-------|-------|-----------|
| Senha forte | `password` | Minimo 12 caracteres, 1 maiuscula, 1 minuscula, 1 digito, 1 especial |
| Historico senha | — | Nao permite reuso das ultimas 6 senhas |
| Expirar senha | — | 90 dias apos criacao/alteracao |
| Bloqueio | — | 5 tentativas de login falhas → 30 minutos de bloqueio |
| Empresa "Outros" | `empresa_observada_outros` | Obrigatorio se `empresa_observada_id` for NULL |
| Data futura | `data_registro` | Nao permitida |
| Janela de edicao | OFS | Observador: 24h | Supervisor: 48h | Gestor/Admin: sem limite |
| Cancelamento | OFS | Apenas Gestor/Admin. Motivo: minimo 10 caracteres. Soft delete (nunca exclusao fisica) |
| Optimistic locking | OFS (PUT) | `updated_at` enviado pelo cliente deve bater com o do banco (409 se conflito) |
| Campos imutaveis | OFS (PUT) | `data_registro`, `hora_registro`, `usuario_id`, snapshots: nunca editaveis |
| OFS Programada | Targets | `meta_ofc_programada = active_people × weekly_target` (calculada via trigger) |
| Restauracao OFS | OFS | Apenas Admin. Apenas registros cancelados. Auditado como CRITICAL |
| Auto-desativacao | Users | Admin nao pode desativar o proprio usuario |
| Auditoria imutavel | `audit_logs` | UPDATE/DELETE bloqueados via trigger PostgreSQL |

---

## PADRAO DE CODIGOS DE ERRO HTTP

| HTTP | Significado | Exemplo no Sistema |
|------|-------------|-------------------|
| 200 | Sucesso | GET, PUT, PATCH bem-sucedidos |
| 201 | Criado | POST bem-sucedido |
| 400 | Requisicao invalida | Query params mal formatados |
| 401 | Nao autenticado | Token ausente, expirado ou invalido |
| 403 | Nao autorizado | Perfil insuficiente para o recurso |
| 404 | Nao encontrado | Recurso nao existe (ID invalido) |
| 409 | Conflito | Optimistic lock, registro ja cancelado |
| 422 | Erro de validacao | Payload invalido (Pydantic), regra de negocio violada |
| 423 | Bloqueado | Usuario bloqueado por tentativas de login |
| 429 | Rate limit | Excedeu 100 req/min (slowapi) |
| 500 | Erro interno | Falha no servidor (inesperado) |

---

**Documento gerado em 13/05/2026 com base nas 8 especificacoes tecnicas do projeto OFS/OFS — Security Dynamics.**
