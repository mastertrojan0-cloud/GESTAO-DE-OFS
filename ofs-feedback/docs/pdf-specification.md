# Especificação de Relatórios PDF — Sistema OFS/OFS

> Security Dynamics — Sistema de Feedback Comportamental
> Stack: WeasyPrint + ReportLab + matplotlib + Jinja2 + FastAPI

---

## 1. Especificações Gerais de Layout PDF

### 1.1 Formato e Dimensões

| Propriedade | Valor |
|---|---|
| Tamanho | A4 (210 mm × 297 mm) |
| Orientação | Retrato (padrão) / Paisagem (gráficos/tabelas grandes) |
| Margens | 20 mm topo, 20 mm base, 20 mm esquerda, 20 mm direita |
| Sangria de header | +5 mm de espaço extra acima do header |
| Fundo | `#FFFFFF` |

### 1.2 Paleta de Cores — Security Dynamics

| Cor | Hex | Uso |
|---|---|---|
| Vermelho institucional | `#CC0000` | Destaques, linhas separadoras, headers de tabela |
| Preto | `#1A1A1A` | Texto principal |
| Cinza claro | `#F5F5F5` | Fundo alternado de tabelas |
| Cinza médio | `#666666` | Texto de rodapé |
| Cinza borda | `#CCCCCC` | Bordas de tabela |
| Branco | `#FFFFFF` | Fundo da página |
| Verde (OK) | `#22C55E` | Status "OK" / Seguro |
| Amarelo (ATENÇÃO) | `#EAB308` | Status "ATENÇÃO" |
| Vermelho (ALERTA) | `#EF4444` | Status "ALERTA" / Inseguro |

### 1.3 Cores de Status

```
┌──────────┬──────────┬───────────────────────────────┐
│ Status   │ Cor      │ Aplicação                      │
├──────────┼──────────┼───────────────────────────────┤
│ OK       │ #22C55E  │ badge verde; texto "OK"        │
│ ATENÇÃO  │ #EAB308  │ badge amarelo; "ATENÇÃO"       │
│ ALERTA   │ #EF4444  │ badge vermelho; "ALERTA"       │
│ SEGURO   │ #22C55E  │ indicador positivo             │
│ INSEGURO │ #EF4444  │ indicador negativo             │
└──────────┴──────────┴───────────────────────────────┘
```

### 1.4 Tipografia

| Elemento | Fonte | Peso | Tamanho | Cor |
|---|---|---|---|---|
| Título do relatório | Inter | Bold | 18pt | `#1A1A1A` |
| Subtítulo | Inter | SemiBold | 14pt | `#CC0000` |
| Título de seção | Inter | Bold | 12pt | `#1A1A1A` |
| Corpo de texto | Inter | Regular | 10pt | `#1A1A1A` |
| Cabeçalho de tabela | Inter | Bold | 9pt | `#FFFFFF` (fundo `#CC0000`) |
| Corpo de tabela | Inter | Regular | 9pt | `#1A1A1A` |
| Rodapé | Inter | Regular | 8pt | `#666666` |

### 1.5 Cabeçalho (Header)

Presente em TODAS as páginas:

```
┌────────────────────────────────────────────────────────────┐
│  ┌──────┐                           SISTEMA DE FEEDBACK   │
│  │ LOGO │                           COMPORTAMENTAL        │
│  │  SD  │                           OFS/OFS               │
│  └──────┘                                                 │
│  ──────────────────────────────────────────────────────── │  ← linha vermelha 1pt
└────────────────────────────────────────────────────────────┘
```

- Logo à esquerda (altura: ~20 mm, preservando proporção)
- Nome do sistema à direita, Inter Bold 10pt
- Linha separadora vermelha (`#CC0000`), 1pt

### 1.6 Rodapé (Footer)

Presente em TODAS as páginas:

```
┌────────────────────────────────────────────────────────────┐
│  ──────────────────────────────────────────────────────── │  ← linha vermelha 1pt
│  Gerado em: 13/05/2026 14:30          Página 1 de 4       │
│       Security Dynamics — Documento gerado                │
│       automaticamente pelo Sistema OFS/OFS                │
└────────────────────────────────────────────────────────────┘
```

- Linha separadora vermelha (`#CC0000`), 1pt
- "Gerado em: DD/MM/AAAA HH:MM" à esquerda, Inter 8pt, `#666666`
- "Página X de Y" à direita
- Centralizado: "Security Dynamics — Documento gerado automaticamente pelo Sistema OFS/OFS"

---

## 2. Relatório Semanal — "MÉTRICAS DA SEMANA"

### 2.1 Layout de Páginas

```
┌─ PÁGINA 1 ──────────────────────────────────────────────────────────┐
│                                                                      │
│  RELATÓRIO SEMANAL DE MÉTRICAS                                       │
│  Semana: 06/05/2026 a 12/05/2026                                     │
│  Empresa: Security Dynamics Ltda.                                    │
│  Gerado por: João Silva                                              │
│  Data de geração: 13/05/2026 14:30                                   │
│                                                                      │
│  ┌─────────────────────── INDICADORES PRINCIPAIS ──────────────────┐ │
│  │ INDICADOR               │ VALOR     │ STATUS       │            │ │
│  │─────────────────────────┼───────────┼──────────────│            │ │
│  │ Pessoas Ativas          │ 50        │ OK           │            │ │
│  │ OFS Programadas         │ 250       │ —            │            │ │
│  │ OFS Realizadas          │ 230       │ —            │            │ │
│  │ Aderência %             │ 92.0%     │ ATENÇÃO      │            │ │
│  │ Positivas               │ 195       │ OK           │            │ │
│  │ Negativas               │ 35        │ ATENÇÃO      │            │ │
│  │ % Seguro                │ 84.8%     │ OK           │            │ │
│  │ % Desvio                │ 15.2%     │ ATENÇÃO      │            │ │
│  │ Usuários Ativos         │ 12        │ OK           │            │ │
│  │ Média OFS / Usuário     │ 19.2      │ OK           │            │ │
│  └─────────────────────────┴───────────┴──────────────┴────────────┘ │
│                                                                      │
│  ┌─ Gráfico 1: Programado × Realizado ─┐ ┌─ Gráfico 2: Positivo × ─┐│
│  │          ██                          │ │     Negativo            ││
│  │     ██   ██    ██                    │ │          ████████       ││
│  │     ██   ██    ██                    │ │     ██████████████      ││
│  │ ────██───██────██───                 │ │     ████  84.8% ████    ││
│  │  Prog  Real  Aderência               │ │     ██████████████      ││
│  └──────────────────────────────────────┘ └─────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘

┌─ PÁGINA 2 ──────────────────────────────────────────────────────────┐
│                                                                      │
│  ┌─ Gráfico 3: OFS por Empresa ─────┐ ┌─ Gráfico 4: OFS por Turno ─┐│
│  │  Empresa A  ██████████████  120  │ │                              ││
│  │  Empresa B  ██████████       80  │ │     ████ Manhã  35%         ││
│  │  Empresa C  ██████          50  │ │     ████ Tarde  40%         ││
│  │  Empresa D  ███             30  │ │     ███  Noite  25%         ││
│  └──────────────────────────────────┘ └─────────────────────────────┘│
│                                                                      │
│  ┌─ Gráfico 5: Evolução Semanal (8 semanas) ────────────────────────┐│
│  │  300 │                                                           ││
│  │  250 │       ●───●───●───●───●───●───●───●                      ││
│  │  200 │   ●───●                                                   ││
│  │  150 │                                                           ││
│  │      └───┴───┴───┴───┴───┴───┴───┴───                           ││
│  │        S1  S2  S3  S4  S5  S6  S7  S8                           ││
│  └──────────────────────────────────────────────────────────────────┘│
│                                                                      │
│  TOP 5 COMPORTAMENTOS SEGUROS              TOP 5 INSEGUROS           │
│  ┌────┬──────────────────────┬──────┐    ┌────┬─────────────────┬───┐│
│  │ #  │ Comportamento        │ Ocor │    │ #  │ Comportamento   │Occ││
│  │ 1  │ Uso correto de EPI  │ 45   │    │ 1  │ Falta de EPI    │12 ││
│  │ 2  │ Sinalização adequada│ 38   │    │ 2  │ Postura incorr. │ 8 ││
│  │ 3  │ Comunicação eficaz  │ 32   │    │ 3  │ Excesso veloc.  │ 7 ││
│  │ 4  │ Organização local   │ 28   │    │ 4  │ Distração       │ 5 ││
│  │ 5  │ Trabalho em equipe  │ 25   │    │ 5  │ Área desorg.    │ 3 ││
│  └────┴──────────────────────┴──────┘    └────┴─────────────────┴───┘│
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │                                                                  ││
│  │  _______________________________________                        ││
│  │  Nome do Gestor                                                  ││
│  │  Gerente de Segurança                                            ││
│  │                                                                  ││
│  │  Data: ___/___/______                                            ││
│  └──────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 Tabela de Indicadores — Regras de Status

| Indicador | Condição OK | Condição ATENÇÃO | Condição ALERTA |
|---|---|---|---|
| Pessoas Ativas | ≥ 30 | 15–29 | < 15 |
| Aderência % | ≥ 85% | 70%–84% | < 70% |
| Positivas | ≥ 80% | 60%–79% | < 60% |
| Negativas | ≤ 15% | 16%–30% | > 30% |
| Média OFS/Usuário | ≥ 15 | 8–14 | < 8 |

---

## 3. Relatório Individual de OFS/OFS

### 3.1 Layout (uma OFS por página)

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  REGISTRO DE OFS/OFS                    Nº OFS: 20250001             │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  DADOS GERAIS                                                  │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  Data: 13/05/2026            Hora: 14:30                       │  │
│  │  Gerado por: João Silva                                        │  │
│  │  Empresa: Security Dynamics Ltda.                              │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  DADOS DA OBSERVAÇÃO                                           │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  Observado: Maria Santos                                       │  │
│  │  Atividade: Operação de ponte rolante                          │  │
│  │  Local: Galpão 3 — Área de Carga                               │  │
│  │  Turno: Manhã (06:00–14:00)                                    │  │
│  │  Tipo: POSITIVO / SEGURO                          ████████████ │  │
│  │                                                    ██ SEGURO ██ │  │
│  │                                                    ████████████ │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  COMPORTAMENTO OBSERVADO                                       │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  Uso correto de EPI: capacete com jugular, óculos de proteção, │  │
│  │  luvas de vaqueta, bota de segurança e protetor auricular.     │  │
│  │  Sinalização adequada da área de movimentação de carga com     │  │
│  │  cones e fita zebrada. Comunicação clara com os colegas.       │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  OBSERVAÇÃO COMPLEMENTAR                                       │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │  O colaborador demonstrou domínio total dos procedimentos de   │  │
│  │  segurança. Atitude proativa ao orientar novos colegas.        │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────┐                                       │
│  │ ██████████████████████████│  Status: ATIVO                        │
│  │ ████ STATUS: ATIVO  █████│                                        │
│  │ ██████████████████████████│                                        │
│  └───────────────────────────┘                                       │
│                                                                      │
│  ───────────────────────────────────────────────────────────────     │
│  Histórico de alterações:                                            │
│  13/05/2026 16:00 — João Silva alterou observação complementar:      │
│    De: "Colaborador atento aos procedimentos."                       │
│    Para: "O colaborador demonstrou domínio total dos procedimentos." │
│  12/05/2026 10:30 — Maria Costa alterou tipo:                         │
│    De: "Positivo"                                                     │
│    Para: "Positivo / Seguro"                                          │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.2 Variante Compacta (meia página)

Para relatórios por empresa ou quando múltiplos OFCs aparecem na mesma página:

```
┌───────────────────────────────┬───────────────────────────────┐
│  Nº 20250001                  │  Nº 20250002                  │
│  Data: 13/05/2026             │  Data: 13/05/2026             │
│  Observado: Maria Santos      │  Observado: Carlos Lima       │
│  Tipo: POSITIVO               │  Tipo: NEGATIVO               │
│  -------------------------    │  -------------------------    │
│  Comportamento: Uso correto   │  Comportamento: Falta de EPI  │
│  de EPI e sinalização...      │  (sem luva e óculos)...      │
│  Status: ATIVO                │  Status: ATIVO                │
└───────────────────────────────┴───────────────────────────────┘
```

---

## 4. Relatório Mensal

### 4.1 Estrutura

```
┌─ PÁGINA 1 ──────────────────────────────────────────────────────────┐
│                                                                      │
│  RELATÓRIO MENSAL DE MÉTRICAS                                        │
│  Mês: Maio/2026                                                      │
│  Empresa: Security Dynamics Ltda.                                    │
│  Gerado por: João Silva                                              │
│  Data de geração: 13/05/2026 14:30                                   │
│                                                                      │
│  ┌─────────────── RESUMO MENSAL ───────────────────────────────────┐ │
│  │ INDICADOR        │ TOTAL    │ MÉDIA/SEM│ STATUS                  │ │
│  │──────────────────┼──────────┼──────────┼────────────────────────│ │
│  │ OFS Realizadas   │ 980      │ 245      │ OK                      │ │
│  │ Positivas        │ 820      │ 205      │ OK                      │ │
│  │ Negativas        │ 160      │ 40       │ ATENÇÃO                 │ │
│  │ Aderência Média  │ 91.5%    │ —        │ OK                      │ │
│  └──────────────────┴──────────┴──────────┴─────────────────────────┘ │
│                                                                      │
│  ┌─── COMPARATIVO SEMANAL ──────────────────────────────────────────┐│
│  │ INDICADOR      │ SEM 1  │ SEM 2  │ SEM 3  │ SEM 4               ││
│  │────────────────┼────────┼────────┼────────┼─────────────────────││
│  │ Realizadas     │ 230    │ 245    │ 260    │ 245                  ││
│  │ Positivas      │ 195    │ 210    │ 215    │ 200                  ││
│  │ Negativas      │ 35     │ 35     │ 45     │ 45                   ││
│  │ Aderência      │ 92.0%  │ 91.5%  │ 90.8%  │ 92.5%               ││
│  └────────────────┴────────┴────────┴────────┴─────────────────────┘│
│                                                                      │
│  ┌─ Evolução Mensal ────────────────────────────────────────────────┐│
│  │  300 │     ██      ██      ██      ██                           ││
│  │  250 │     ██ ██   ██ ██   ██ ██   ██ ██                        ││
│  │  200 │     ██ ██   ██ ██   ██ ██   ██ ██                        ││
│  │  150 │     ██ ██   ██ ██   ██ ██   ██ ██                        ││
│  │      └─────┴──┴────┴──┴────┴──┴────┴──┴──                        ││
│  │           S1      S2      S3      S4                             ││
│  │        Programado ██    Realizado ██                              ││
│  └──────────────────────────────────────────────────────────────────┘│
│                                                                      │
│  ┌─ TENDÊNCIA vs MÊS ANTERIOR ──────────────────────────────────────┐│
│  │                                                                    ││
│  │  OFS Realizadas: 980  ↑  (Abril: 920, +6.5%)                     ││
│  │  Aderência: 91.5%    →  (Abril: 91.2%, estável)                  ││
│  │  Positivas: 84%      ↓  (Abril: 87%, -3pp)                       ││
│  │                                                                    ││
│  └───────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

### 4.2 Símbolos de Tendência

| Símbolo | Significado | Condição |
|---|---|---|
| ↑ | Melhora | Variação > +3% |
| ↓ | Piora | Variação < -3% |
| → | Estável | Variação entre -3% e +3% |

---

## 5. Relatório por Empresa

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  RELATÓRIO POR EMPRESA                                               │
│  Empresa: Security Dynamics Ltda.                                    │
│  Período: 01/05/2026 a 13/05/2026                                    │
│                                                                      │
│  ┌─────────────── RESUMO ──────────────────────────────────────────┐ │
│  │ OFS Programadas │ OFS Realizadas │ Positivas │ Negativas        │ │
│  │─────────────────┼────────────────┼───────────┼──────────────────│ │
│  │ 120             │ 115            │ 98        │ 17                │ │
│  └─────────────────┴────────────────┴───────────┴──────────────────┘ │
│                                                                      │
│  ── OFCs POSITIVAS ──────────────────────────────────────────────    │
│                                                                      │
│  ┌───────────────────────────────┬───────────────────────────────┐   │
│  │ Nº 20250001 — 10/05/2026     │ Nº 20250002 — 11/05/2026     │   │
│  │ Obs: Maria Santos            │ Obs: Carlos Lima              │   │
│  │ Uso correto de EPI e         │ Sinalização adequada da       │   │
│  │ sinalização.                 │ área de trabalho.             │   │
│  │ Status: ATIVO                │ Status: ATIVO                 │   │
│  └───────────────────────────────┴───────────────────────────────┘   │
│                                                                      │
│  ── OFCs NEGATIVAS ──────────────────────────────────────────────    │
│                                                                      │
│  ┌───────────────────────────────┐                                   │
│  │ Nº 20250010 — 12/05/2026     │                                   │
│  │ Obs: Pedro Alves             │                                   │
│  │ Falta de EPI (sem óculos     │                                   │
│  │ de proteção).                │                                   │
│  │ Status: ATIVO                │                                   │
│  └───────────────────────────────┘                                   │
│                                                                      │
│  ── OFCs CANCELADAS ─────────────────────────────────────────────    │
│                                                                      │
│  ┌───────────────────────────────┐                                   │
│  │ Nº 20250015 — 09/05/2026     │                                   │
│  │ Obs: Ana Costa               │                                   │
│  │ Postura inadequada (erro     │                                   │
│  │ de registro).                │                                   │
│  │ Status: CANCELADO            │                                   │
│  └───────────────────────────────┘                                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 6. Especificações Técnicas

### 6.1 Pipeline de Geração

```
1. API recebe requisição: POST /api/reports/generate
   Body: { type, company_id, start_date, end_date, user_id }

2. pdf_service.py valida parâmetros e inicia job

3. Busca dados:
   - ofc_records (tabela principal)
   - ofc_behaviors (comportamentos observados)
   - metrics_cache (métricas pré-calculadas)
   - users, companies (dados auxiliares)

4. chart_service.py gera PNGs (matplotlib):
   - Gráficos são salvos em buffer BytesIO (memória)
   - Convertidos para base64 para embed no HTML
   - Cache de gráficos em /tmp/charts_cache/ (TTL: 1 hora)

5. Template HTML Jinja2 renderizado:
   - Dados injetados + PNGs em base64
   - CSS completo inline (WeasyPrint não carrega CSS externo)

6. WeasyPrint converte HTML → PDF:
   - HTML(string=html_content)
   - pdf = doc.write_pdf()

7. PDF salvo:
   - Path: /app/reports/{type}/{YYYY}/{MM}/{uuid}.pdf
   - Registro na tabela reports com: id, type, file_path, size,
     created_at, created_by, filters (JSON), download_count

8. Resposta API:
   {
     "report_id": "uuid",
     "download_url": "/api/reports/download/uuid",
     "file_name": "relatorio_semanal_20260513.pdf",
     "file_size": 245760,
     "generated_at": "2026-05-13T14:30:00Z"
   }
```

### 6.2 Tabela `reports` (SQL)

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(50) NOT NULL,           -- 'weekly', 'monthly', 'individual', 'company'
    title VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    page_count INTEGER DEFAULT 1,
    filters JSONB NOT NULL DEFAULT '{}', -- {company_id, start_date, end_date, ...}
    status VARCHAR(20) DEFAULT 'completed', -- 'processing', 'completed', 'failed'
    error_message TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    download_count INTEGER DEFAULT 0,
    last_downloaded_at TIMESTAMPTZ
);
```

### 6.3 Endpoints da API

```
GET  /api/reports/types                    — Lista tipos de relatório disponíveis
POST /api/reports/generate                 — Gera um novo relatório
GET  /api/reports/history                  — Histórico de relatórios gerados (paginado)
GET  /api/reports/download/{report_id}     — Download do PDF
DELETE /api/reports/{report_id}            — Remove relatório
GET  /api/reports/preview/{report_id}      — Preview inline (HTML)
```

---

## 7. CSS Base para Templates

### 7.1 Base CSS (`_base.css` — inline no template)

```css
@page {
  size: A4;
  margin: 20mm 20mm 25mm 20mm;

  @top-center {
    content: element(pageHeader);
  }

  @bottom-center {
    content: element(pageFooter);
  }
}

@page landscape {
  size: A4 landscape;
  margin: 15mm 15mm 22mm 15mm;
}

body {
  font-family: 'Inter', Arial, sans-serif;
  font-size: 10pt;
  color: #1A1A1A;
  line-height: 1.5;
}

/* ── Header ── */
.header {
  position: running(pageHeader);
  width: 100%;
  padding-bottom: 8px;
  border-bottom: 1.5pt solid #CC0000;
  margin-bottom: 10mm;
}

.header-container {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-logo {
  height: 20mm;
  width: auto;
}

.header-title {
  text-align: right;
  font-size: 10pt;
  font-weight: 700;
  color: #1A1A1A;
}

.header-title span {
  display: block;
  font-size: 8pt;
  font-weight: 400;
  color: #666666;
}

/* ── Footer ── */
.footer {
  position: running(pageFooter);
  width: 100%;
  border-top: 1.5pt solid #CC0000;
  padding-top: 14px;
  font-size: 8pt;
  color: #666666;
}

.footer-row {
  display: flex;
  justify-content: space-between;
}

.footer-center {
  text-align: center;
  margin-top: -2px;
  font-size: 7pt;
}

/* ── Tipografia ── */
.report-title {
  font-size: 18pt;
  font-weight: 700;
  color: #1A1A1A;
  margin-bottom: 4mm;
  text-transform: uppercase;
  letter-spacing: 0.5pt;
}

.report-subtitle {
  font-size: 14pt;
  font-weight: 600;
  color: #CC0000;
  margin-bottom: 3mm;
}

.section-title {
  font-size: 12pt;
  font-weight: 700;
  color: #1A1A1A;
  margin-top: 6mm;
  margin-bottom: 3mm;
  padding-bottom: 1mm;
  border-bottom: 1pt solid #CCCCCC;
}

/* ── Meta Info Box ── */
.meta-box {
  background: #F5F5F5;
  border-left: 3pt solid #CC0000;
  padding: 4mm 6mm;
  margin-bottom: 5mm;
}

.meta-row {
  display: flex;
  gap: 15mm;
  font-size: 10pt;
}

.meta-label {
  font-weight: 600;
  color: #666666;
  min-width: 35mm;
}

/* ── Tabelas ── */
.data-table {
  width: 100%;
  border-collapse: collapse;
  margin-bottom: 5mm;
  font-size: 9pt;
}

.data-table thead th {
  background: #CC0000;
  color: #FFFFFF;
  padding: 8px 10px;
  text-align: left;
  font-weight: 700;
  font-size: 9pt;
}

.data-table tbody td {
  padding: 6px 10px;
  border-bottom: 0.5pt solid #CCCCCC;
  vertical-align: middle;
}

.data-table tbody tr:nth-child(even) {
  background: #F5F5F5;
}

.data-table tbody tr:nth-child(odd) {
  background: #FFFFFF;
}

.data-table .number {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* ── Status Badges ── */
.badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 3px;
  font-size: 8pt;
  font-weight: 700;
  text-transform: uppercase;
}

.badge-ok       { background: #22C55E; color: #FFFFFF; }
.badge-atencao  { background: #EAB308; color: #1A1A1A; }
.badge-alerta   { background: #EF4444; color: #FFFFFF; }
.badge-seguro   { background: #22C55E; color: #FFFFFF; }
.badge-inseguro { background: #EF4444; color: #FFFFFF; }
.badge-cancelado { background: #999999; color: #FFFFFF; }
.badge-editado  { background: #3B82F6; color: #FFFFFF; }

/* ── Chart Container ── */
.chart-container {
  margin: 4mm 0;
  text-align: center;
  page-break-inside: avoid;
}

.chart-container img {
  max-width: 100%;
  height: auto;
}

.chart-row {
  display: flex;
  gap: 5mm;
  justify-content: space-between;
}

.chart-row .chart-container {
  flex: 1;
}

/* ── OFS Card ── */
.OFS-card {
  border: 1pt solid #CCCCCC;
  border-radius: 3px;
  padding: 4mm;
  margin-bottom: 4mm;
  page-break-inside: avoid;
}

.OFS-card.positivo {
  border-left: 4pt solid #22C55E;
}

.OFS-card.negativo {
  border-left: 4pt solid #EF4444;
}

.OFS-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2mm;
  padding-bottom: 2mm;
  border-bottom: 1pt solid #E5E5E5;
}

.OFS-card-title {
  font-size: 11pt;
  font-weight: 700;
}

.OFS-card-field {
  display: flex;
  margin-bottom: 1.5mm;
}

.OFS-card-label {
  font-weight: 600;
  min-width: 35mm;
  color: #666666;
  font-size: 9pt;
}

.OFS-card-value {
  font-size: 9pt;
}

/* ── History block ── */
.history-block {
  margin-top: 3mm;
  padding-top: 2mm;
  border-top: 0.5pt dashed #CCCCCC;
  font-size: 8pt;
}

.history-entry {
  margin-bottom: 1.5mm;
  padding-left: 5mm;
}

.history-meta {
  color: #666666;
  margin-bottom: 0.5mm;
}

.history-change {
  display: flex;
  gap: 3mm;
}

.history-from {
  color: #EF4444;
  text-decoration: line-through;
}

.history-to {
  color: #22C55E;
}

/* ── Assinatura ── */
.signature-block {
  margin-top: 15mm;
  text-align: center;
  page-break-inside: avoid;
}

.signature-line {
  width: 60%;
  margin: 0 auto 3mm;
  border-bottom: 1pt solid #1A1A1A;
}

.signature-name {
  font-weight: 600;
  font-size: 11pt;
}

.signature-role {
  font-size: 9pt;
  color: #666666;
}

.signature-date {
  margin-top: 5mm;
  font-size: 9pt;
}

/* ── Tendências ── */
.trend-up    { color: #22C55E; font-weight: 700; }
.trend-down  { color: #EF4444; font-weight: 700; }
.trend-stable{ color: #666666; font-weight: 700; }

/* ── Paisagem ── */
.landscape-page {
  page: landscape;
}

/* ── Page break control ── */
.page-break { page-break-before: always; }
.no-break   { page-break-inside: avoid; }
```

---

## 8. Otimizações

### 8.1 Cache de Templates Jinja2
```python
from jinja2 import Environment, FileSystemLoader, select_autoescape

env = Environment(
    loader=FileSystemLoader("backend/app/templates"),
    autoescape=select_autoescape(["html"]),
    enable_async=True,
    cache_size=50,  # Cache de templates compilados
)
```

### 8.2 Pool de Figuras Matplotlib
```python
import matplotlib
matplotlib.use("Agg")  # Backend não-interativo

from matplotlib.figure import Figure
from concurrent.futures import ThreadPoolExecutor

chart_executor = ThreadPoolExecutor(max_workers=4)

def generate_chart_async(chart_type, data):
    """Gera gráfico em thread separada para não bloquear."""
    return chart_executor.submit(_render_chart, chart_type, data)
```

### 8.3 Geração Assíncrona (FastAPI BackgroundTasks)
```python
from fastapi import BackgroundTasks

@router.post("/generate")
async def generate_report(
    request: ReportRequest,
    background_tasks: BackgroundTasks
):
    report_id = str(uuid.uuid4())
    # Cria registro como 'processing'
    background_tasks.add_task(build_report_pdf, report_id, request)
    return {"report_id": report_id, "status": "processing"}
```

### 8.4 Compressão de PNG
```python
from PIL import Image
import io

def compress_png(image_bytes: bytes, quality: int = 85) -> bytes:
    """Comprime PNG para reduzir tamanho do PDF."""
    img = Image.open(io.BytesIO(image_bytes))
    output = io.BytesIO()
    img.save(output, format="PNG", optimize=True)
    return output.getvalue()
```

### 8.5 Cache de Gráficos (disco)
```python
import hashlib, os
from pathlib import Path

CHART_CACHE_DIR = Path("/tmp/charts_cache")
CHART_CACHE_DIR.mkdir(exist_ok=True)

def get_cached_chart(chart_type: str, params: dict) -> bytes | None:
    key = hashlib.md5(f"{chart_type}:{sorted(params.items())}".encode()).hexdigest()
    cache_path = CHART_CACHE_DIR / f"{key}.png"
    if cache_path.exists() and (time.time() - cache_path.stat().st_mtime) < 3600:
        return cache_path.read_bytes()
    return None
```

### 8.6 Timeout / Rate Limit
```python
PDF_GENERATION_TIMEOUT = 60  # segundos
MAX_CONCURRENT_GENERATIONS = 4
```

---

## 9. Exemplo Visual — Página 1 do Relatório Semanal

```
╔══════════════════════════════════════════════════════════════════════════╗
║ ┌──────────────────────────────────────────────────────────────────────┐║
║ │  ┌──────────────┐                   SISTEMA DE FEEDBACK              │║
║ │  │ ████████████ │                   COMPORTAMENTAL                   │║
║ │  │ ██  LOGO  ██ │                   OFS/OFS                          │║
║ │  │ ██   SD   ██ │                                                   │║
║ │  │ ████████████ │                                                   │║
║ │  └──────────────┘                                                   │║
║ │ ═══════════════════════════════════════════════════════════════════  │║
║ ╞══════════════════════════════════════════════════════════════════════╡║
║ │                                                                      │║
║ │  RELATÓRIO SEMANAL DE MÉTRICAS                                       │║
║ │  ─────────────────────────────                                       │║
║ │                                                                      │║
║ │  ┌──────────────────────────────────────────────────────────────┐    │║
║ │  │  Semana: 06/05/2026 — 12/05/2026                             │    │║
║ │  │  Empresa: Security Dynamics Ltda.                            │    │║
║ │  │  Gerado por: João Silva — Gerente de Segurança               │    │║
║ │  │  Data de geração: 13/05/2026 14:30:00                        │    │║
║ │  └──────────────────────────────────────────────────────────────┘    │║
║ │                                                                      │║
║ │  ┌──────────────────────────────────────────────────────────────┐    │║
║ │  │                      INDICADORES PRINCIPAIS                  │    │║
║ │  ├─────────────────────────────┬───────────────┬────────────────┤    │║
║ │  │ INDICADOR                   │ VALOR         │ STATUS         │    │║
║ │  ├─────────────────────────────┼───────────────┼────────────────┤    │║
║ │  │ Pessoas Ativas              │ 50            │    ████ OK ████│    │║
║ │  │ OFS Programadas             │ 250           │      —         │    │║
║ │  │ OFS Realizadas              │ 230           │      —         │    │║
║ │  │ Aderência %                 │ 92.0%         │■■ ATENÇÃO ■■■■■│    │║
║ │  │ Positivas                   │ 195           │    ████ OK ████│    │║
║ │  │ Negativas                   │ 35            │■■ ATENÇÃO ■■■■■│    │║
║ │  │ % Seguro                    │ 84.8%         │    ████ OK ████│    │║
║ │  │ % Desvio                    │ 15.2%         │■■ ATENÇÃO ■■■■■│    │║
║ │  │ Usuários Ativos             │ 12            │    ████ OK ████│    │║
║ │  │ Média OFS / Usuário         │ 19.2          │    ████ OK ████│    │║
║ │  └─────────────────────────────┴───────────────┴────────────────┘    │║
║ │                                                                      │║
║ │  ┌──────────────────┐          ┌──────────────────────┐             │║
║ │  │  Programado ×    │          │  POSITIVO × NEGATIVO │             │║
║ │  │  Realizado       │          │                      │             │║
║ │  │       ████       │          │     ┌──────────┐    │             │║
║ │  │  ████ ████ ████  │          │     │░░░░░░░░░░│    │             │║
║ │  │  ████ ████ ████  │          │     │░░ 84.8%░ │    │             │║
║ │  │  ████ ████ ████  │          │     │░░░░░░░░░░│    │             │║
║ │  │  ████ ████ ████  │          │     └──────────┘    │             │║
║ │  │  Prog Real Ader │          │  ████ Seguro 195     │             │║
║ │  └──────────────────┘          │  ░░░░ Desvio  35    │             │║
║ │                                └──────────────────────┘             │║
║ │                                                                      │║
║ │ ═══════════════════════════════════════════════════════════════════  │║
║ │ Gerado em: 13/05/2026 14:30               Página 1 de 3             │║
║ │     Security Dynamics — Documento gerado automaticamente pelo       │║
║ │     Sistema OFS/OFS                                                  │║
║ ╞══════════════════════════════════════════════════════════════════════╡║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## 10. Diagrama de Componentes

```
┌──────────┐    ┌─────────────┐    ┌────────────────┐    ┌──────────┐
│ Frontend │───▶│  FastAPI     │───▶│  pdf_service   │───▶│  Database│
│ (React)  │    │  /api/       │    │  .py            │    │  (Post-  │
│          │    │  reports/    │    │                 │    │   greSQL) │
└──────────┘    │              │    │  1. coleta dados│    └──────────┘
                │              │    │  2. gera gráfico│
                │              │    │  3. renderiza   │    ┌──────────┐
                │              │    │     template    │───▶│ chart_   │
                │              │    │  4. WeasyPrint  │    │ service  │
                │              │    │  5. salva PDF   │    │ .py      │
                │              │    │  6. registra    │    │ matplotlib│
                │              │    │                 │    └──────────┘
                │              │    └────────┬────────┘
                │              │             │
                │◀─────────────│    ┌────────▼────────┐
                │  download_url│    │  /app/reports/   │
                └──────────────┘    │  {type}/{YYYY}/  │
                                    │  {MM}/{uuid}.pdf │
                                    └─────────────────┘
```

---

*Documento de especificação — Versão 1.0 — Security Dynamics — Maio/2026*
