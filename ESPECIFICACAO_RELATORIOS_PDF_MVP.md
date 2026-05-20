# ESPECIFICAÇÃO DE RELATÓRIOS, GRÁFICOS E PDFs — MVP

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Estrutura Visual dos PDFs](#1-estrutura-visual-dos-pdfs)
2. [Wireframe Textual — Relatório Individual OFS/OFS](#2-wireframe-textual--relatório-individual-ofcofs)
3. [Wireframe Textual — Relatório MÉTRICAS DA SEMANA](#3-wireframe-textual--relatório-métricas-da-semana)
4. [Wireframe Textual — Relatório Mensal](#4-wireframe-textual--relatório-mensal)
5. [Wireframe Textual — Ranking por Empresa](#5-wireframe-textual--ranking-por-empresa)
6. [Wireframe Textual — Ranking por Usuário](#6-wireframe-textual--ranking-por-usuário)
7. [Wireframe Textual — Histórico de Desvios](#7-wireframe-textual--histórico-de-desvios)
8. [Lista de Gráficos e Especificações](#8-lista-de-gráficos-e-especificações)
9. [Fórmulas dos Indicadores](#9-fórmulas-dos-indicadores)
10. [Regras de Exportação](#10-regras-de-exportação)
11. [Padrão de Nomes de Arquivos](#11-padrão-de-nomes-de-arquivos)
12. [Estratégia para Geração Local de PDF](#12-estratégia-para-geração-local-de-pdf)
13. [Estratégia para Inclusão do Logotipo](#13-estratégia-para-inclusão-do-logotipo)
14. [Estratégia para Gráficos no PDF](#14-estratégia-para-gráficos-no-pdf)
15. [Regras de Auditoria para Exportações](#15-regras-de-auditoria-para-exportações)
16. [Critérios de Aceite dos Relatórios](#16-critérios-de-aceite-dos-relatórios)

---

## 1. Estrutura Visual dos PDFs

### 1.1 Template Base (aplicado a todos os relatórios)

```
┌─────────────────────────────────────────────────────┐ ◄── Margem 20mm
│ ╔═══════════════════════════════════════════════════╗ │
│ ║                CABEÇALHO (fixo)                   ║ │
│ ╠═══════════════════════════════════════════════════╣ │
│ ║ ┌──────────┐                        ┌──────────┐ ║ │
│ ║ │          │     SISTEMA DE         │          │ ║ │
│ ║ │  [LOGO]  │     FEEDBACK           │  TÍTULO  │ ║ │
│ ║ │          │     COMPORTAMENTAL     │    DO     │ ║ │
│ ║ │          │     OFS / OFS          │RELATÓRIO  │ ║ │
│ ║ └──────────┘                        └──────────┘ ║ │
│ ╚═══════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════  │ ◄── Linha vermelha 1pt
│                                                       │
│                                                       │
│                 CONTEÚDO DO RELATÓRIO                 │
│            (varia conforme tipo de relatório)         │
│                                                       │
│                                                       │
│ ═══════════════════════════════════════════════════  │ ◄── Linha vermelha 0.5pt
│ ╔═══════════════════════════════════════════════════╗ │
│ ║                RODAPÉ (fixo)                      ║ │
│ ╠═══════════════════════════════════════════════════╣ │
│ ║ Gerado em: DD/MM/AAAA HH:MM     │   Página X de Y ║ │
│ ║ Security Dynamics — Sistema OFS/OFS                ║ │
│ ║ Documento gerado automaticamente                   ║ │
│ ╚═══════════════════════════════════════════════════╝ │
└─────────────────────────────────────────────────────┘ ◄── Margem 20mm
```

### 1.2 Especificações Técnicas da Página

```css
@page {
  size: A4;                          /* 210mm × 297mm */
  margin: 20mm 20mm 28mm 20mm;       /* top right bottom left */
  
  @top-center {
    content: element(pageHeader);     /* Cabeçalho fixo */
  }
  
  @bottom-center {
    content: element(pageFooter);     /* Rodapé fixo */
  }
}

/* Orientação paisagem para tabelas grandes */
@page landscape {
  size: A4 landscape;
  margin: 18mm 18mm 26mm 18mm;
}
```

### 1.3 Grid de Conteúdo (após cabeçalho)

```
┌─────────────────────────────────────────────────────┐
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │ TÍTULO DO RELATÓRIO (18pt Bold, preto)          │ │
│  │ Período: DD/MM/AAAA a DD/MM/AAAA (12pt, cinza)  │ │
│  │ Filtros: Empresa X | Contrato Y | Turno Z       │ │
│  │ Emitido por: Nome do Usuário (12pt, cinza)       │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │            CONTEÚDO PRINCIPAL                     │ │
│  │     (tabelas, gráficos, indicadores)              │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### 1.4 Paleta de Cores Aplicada aos PDFs

| Cor | Hex | USO |
|-----|-----|-----|
| Vermelho institucional (primária) | `#CC0000` | Linhas separadoras, cabeçalho de tabela, títulos de seção |
| Vermelho escuro (hover/destaque) | `#990000` | Texto em fundo claro para destaque |
| Preto (texto principal) | `#1A1A1A` | Texto do corpo, títulos |
| Cinza escuro (texto secundário) | `#4B5563` | Subtítulos, metadados |
| Cinza médio (bordas suaves) | `#9CA3AF` | Bordas de tabelas internas |
| Cinza claro (fundo alternado) | `#F5F5F5` | Fundo de linhas alternadas em tabelas |
| Branco (fundo) | `#FFFFFF` | Fundo da página |
| Verde (sucesso/seguro) | `#22C55E` | Tipo Positivo, Status OK, % Seguro |
| Amarelo (atenção) | `#EAB308` | Status ATENÇÃO |
| Vermelho (alerta/perigo) | `#EF4444` | Tipo Negativo, Status ALERTA, % Desvio |

### 1.5 Tipografia nos PDFs

```
Fonte: Inter (arquivos .woff2 incluídos no backend)

┌──────────┬────────┬───────┬─────────────────────────┐
│ Elemento │ Peso   │ Tam.  │ Cor                     │
├──────────┼────────┼───────┼─────────────────────────┤
│ Título   │ Bold   │ 18pt  │ #1A1A1A (preto)         │
│ Subtítulo│ SemiBold│ 14pt │ #CC0000 (vermelho)      │
│ Seção    │ Bold   │ 12pt  │ #1A1A1A                 │
│ Corpo    │ Regular│ 10pt  │ #1A1A1A                 │
│ Tabela TH│ Bold   │ 9pt   │ #FFFFFF (sobre #CC0000) │
│ Tabela TD│ Regular│ 9pt   │ #1A1A1A                 │
│ Rodapé   │ Regular│ 8pt   │ #9CA3AF                 │
│ Código   │ Bold   │ 22pt  │ #CC0000 (destaque nº)   │
└──────────┴────────┴───────┴─────────────────────────┘
```

### 1.6 Comportamento de Quebra de Página

```
- Título do relatório + metadados: NUNCA quebrar entre página
- Tabela: cabeçalho repete no topo da nova página
- Gráfico: se não couber na página atual, quebrar antes
- Seção "Comportamento Observado": NUNCA quebrar no meio
- Rodapé: presente em TODAS as páginas
- Página 1: inclui cabeçalho completo
- Páginas 2+: cabeçalho simplificado (apenas logo + nome sistema)
```

---

## 2. Wireframe Textual — Relatório Individual OFS/OFS

```
┌─────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════╗ │
│ ║ [LOGO SD]              SISTEMA OFS/OFS     RELATÓRIO INDIV.  ║ │
│ ╚═══════════════════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════════════════  │
│                                                                   │
│  RELATÓRIO INDIVIDUAL OFS/OFS                                     │
│  ─────────────────────────────────────                            │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                              │ │
│  │                    Nº OFS/OFS: 1523                          │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════ DADOS DO REGISTRO ═══════════                        │
│                                                                   │
│  ┌─────────────────────────┬───────────────────────────────────┐ │
│  │ Data: 13/05/2026        │ Hora: 14:30                       │ │
│  │ Semana: 20/2026         │ Mês: Maio/2026                    │ │
│  └─────────────────────────┴───────────────────────────────────┘ │
│                                                                   │
│  ═══════════ USUÁRIO GERADOR ═══════════                          │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Nome: Carlos Henrique Oliveira                               │ │
│  │ Login: carlos.oliveira                                       │ │
│  │ E-mail: carlos.oliveira@securitydynamics.com.br              │ │
│  │ Perfil: Supervisor                                           │ │
│  │ Empresa: Security Dynamics                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════ DADOS DA OBSERVAÇÃO ═══════════                      │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Empresa Observada: Security Dynamics                         │ │
│  │ Contrato: Operação Security Dynamics                         │ │
│  │ Nome do Observado: João Silva Santos                         │ │
│  │ Atividade Observada: Operação de empilhadeira no armazém B   │ │
│  │ Local: Armazém B                                             │ │
│  │ Turno: Diurno                                                │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════ CLASSIFICAÇÃO ═══════════                             │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                              │ │
│  │     ✅ POSITIVO / SEGURO                                     │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════ COMPORTAMENTO OBSERVADO ═══════════                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                                                              │ │
│  │  Uso correto de todos os EPIs obrigatórios: capacete, luva,  │ │
│  │  bota e colete. Verificou área antes de iniciar operação.    │ │
│  │  Sinalizou corretamente o local de trabalho.                 │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════ OBSERVAÇÃO COMPLEMENTAR ═══════════                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Operador demonstrou atenção redobrada aos procedimentos de  │ │
│  │  segurança. Conhece todos os protocolos da área.             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════ STATUS E HISTÓRICO ═══════════                       │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Status: GERADO                         🟢                    │ │
│  │                                                              │ │
│  │ Criado por: Carlos Henrique Oliveira                         │ │
│  │ Criado em: 13/05/2026 14:30                                  │ │
│  │                                                              │ │
│  │ Histórico de alterações:                                     │ │
│  │ ┌──────────┬────────────┬──────────┬──────────┬──────────┐  │ │
│  │ │ Data     │ Usuário    │ Campo    │ De       │ Para     │  │ │
│  │ ├──────────┼────────────┼──────────┼──────────┼──────────┤  │ │
│  │ │13/05 16:4│Carlos O.   │Comportam.│Uso corr..│Uso corr..│  │ │
│  │ │13/05 16:4│Carlos O.   │Observação│Operador..│Operador..│  │ │
│  │ └──────────┴────────────┴──────────┴──────────┴──────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ═══════════════════════════════════════════════════════════════  │
│  Gerado em: 13/05/2026 14:45             │   Página 1 de 1       │
│  Security Dynamics — Sistema OFS/OFS                              │
│  Documento gerado automaticamente                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 Variação: OFS Cancelado

```
┌─────────────────────────────────────────────────────────────┐
│ Status: CANCELADO                         🔴                │
│                                                              │
│ Cancelado por: Administrador do Sistema                      │
│ Cancelado em: 15/05/2026 09:00                               │
│ Motivo: Registro duplicado — OFS já havia sido criado pelo   │
│         usuário Pedro Costa                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Wireframe Textual — Relatório MÉTRICAS DA SEMANA

```
┌─────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════╗ │
│ ║ [LOGO SD]              SISTEMA OFS/OFS     RELATÓRIO SEMANAL ║ │
│ ╚═══════════════════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════════════════  │
│                                                                   │
│  RELATÓRIO DE MÉTRICAS SEMANAIS                                   │
│  ─────────────────────────────────────                             │
│  Semana: 20/2026  │  Período: 11/05/2026 a 17/05/2026             │
│  Contrato: Operação Security Dynamics                              │
│  Empresa: Security Dynamics                                        │
│  Turno: Todos    │    Usuário: Todos                               │
│  Emitido por: Carlos Henrique Oliveira  │  13/05/2026 14:45        │
│                                                                   │
│  ═══════════ INDICADORES PRINCIPAIS ═══════════                    │
│                                                                   │
│  ┌─────────────────┬─────────────────┬───────────────────────┐    │
│  │   ADERÊNCIA     │    % SEGURO     │       STATUS          │    │
│  │                 │                 │                        │    │
│  │     86.0%       │     80.6%       │     🟡 ATENÇÃO         │    │
│  │                 │                 │                        │    │
│  │  Meta: ≥100%    │  Meta: ≥90%     │  Aderência entre       │    │
│  │                 │                 │  80% e 99%             │    │
│  └─────────────────┴─────────────────┴───────────────────────┘    │
│                                                                   │
│  ═══════════ INDICADORES DETALHADOS ═══════════                    │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │                                                            │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │    │
│  │  │   Pessoas   │  │    OFS      │  │    OFS      │        │    │
│  │  │   Ativas    │  │ Programadas │  │ Realizadas  │        │    │
│  │  │             │  │             │  │             │        │    │
│  │  │    150      │  │    750      │  │    645      │        │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │    │
│  │                                                            │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │    │
│  │  │  Positivas  │  │  Negativas  │  │  Usuários   │        │    │
│  │  │             │  │             │  │   Ativos    │        │    │
│  │  │    520      │  │    125      │  │     9       │        │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │    │
│  │                                                            │    │
│  │  ┌─────────────┐  ┌─────────────┐                          │    │
│  │  │  Média por  │  │  % Desvio   │                          │    │
│  │  │  Usuário    │  │             │                          │    │
│  │  │    71.7     │  │   19.4%     │                          │    │
│  │  └─────────────┘  └─────────────┘                          │    │
│  └───────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ═══════════ GRÁFICOS ═══════════                                  │
│                                                                   │
│  ┌──────────────────────────────────┐ ┌────────────────────────┐  │
│  │  PROGRAMADO x REALIZADO          │ │  POSITIVO x NEGATIVO   │  │
│  │                                  │ │                        │  │
│  │  800┤ ▓▓▓▓▓▓▓▓▓▓▓               │ │      ┌────────┐       │  │
│  │  600┤ ▓▓▓▓▓▓▓▓▓▓▓  ▒▒▒▒▒▒▒▒     │ │      │80.6%   │ verde │  │
│  │  400┤ ▓▓▓▓▓▓▓▓▓▓▓  ▒▒▒▒▒▒▒▒     │ │      │Positivo│       │  │
│  │  200┤ ▓▓▓▓▓▓▓▓▓▓▓  ▒▒▒▒▒▒▒▒     │ │      │        │       │  │
│  │    0┤ ▓▓▓▓▓▓▓▓▓▓▓  ▒▒▒▒▒▒▒▒     │ │      │19.4%   │ verm. │  │
│  │      └──────┬───────┘            │ │      │Negativo│       │  │
│  │       Program.  Realiz.          │ │      └────────┘       │  │
│  └──────────────────────────────────┘ └────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────┐ ┌────────────────────────┐  │
│  │  OFS POR EMPRESA                 │ │  OFS POR USUÁRIO       │  │
│  │                                  │ │                        │  │
│  │  SD     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 645     │ │  Carlos  ▓▓▓▓▓▓▓ 85   │  │
│  │  G4S    ▓▓▓▓▓▓▓▓▓▓  380         │ │  Ana     ▓▓▓▓▓▓  72   │  │
│  │  ERA    ▓▓▓▓▓▓▓▓▓▓▓  510        │ │  Pedro   ▓▓▓▓▓   58   │  │
│  │  P.Norte▓▓▓▓▓  200             │ │  Julia   ▓▓▓▓    45   │  │
│  │  Sodexo ▓▓▓▓▓▓  250            │ │  Marcos  ▓▓▓▓    42   │  │
│  └──────────────────────────────────┘ └────────────────────────┘  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  OFS POR TURNO                                              │   │
│  │                                                             │   │
│  │       ┌────────────┐                                        │   │
│  │       │ Diurno 43% │                                        │   │
│  │       │ Noturno33% │                                        │   │
│  │       │ ADM    16% │                                        │   │
│  │       │ Misto   8% │                                        │   │
│  │       └────────────┘                                        │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  EVOLUÇÃO SEMANAL (últimas 8 semanas)                       │   │
│  │                                                             │   │
│  │  120%┤                                                     │   │
│  │  100%┤──●──●──●────●──●                                    │   │
│  │   80%┤                 ●──●──●                             │   │
│  │   60%┤                                                     │   │
│  │      ├────┼────┼────┼────┼────┼────┼────┼────              │   │
│  │      S13  S14  S15  S16  S17  S18  S19  S20               │   │
│  │                                                             │   │
│  │   ─── Meta 100%    ─ ─ Alerta 80%    ● Aderência real      │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ═══════════ TABELA CONSOLIDADA ═══════════                        │
│                                                                   │
│  ┌──────────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐    │
│  │ Contrato/│Pes.At│Prog. │Real. │Posit.│Negat.│Ader.%│Status│    │
│  │ Empresa  │      │      │      │      │      │      │      │    │
│  ├──────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤    │
│  │OperaçãoSD│ 150  │ 750  │ 645  │ 520  │ 125  │ 86.0%│ ATEN │    │
│  │G4S       │  80  │ 400  │ 380  │ 310  │  70  │ 95.0%│ ATEN │    │
│  │ERA       │ 100  │ 500  │ 510  │ 450  │  60  │102.0%│  OK  │    │
│  │Polo Norte│  50  │ 250  │ 200  │ 160  │  40  │ 80.0%│ ATEN │    │
│  │Sodexo    │  60  │ 300  │ 250  │ 210  │  40  │ 83.3%│ ATEN │    │
│  └──────────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘    │
│                                                                   │
│  ═══════════════════════════════════════════════════════════════  │
│  Gerado em: 13/05/2026 14:45             │   Página 1 de 2       │
│  Security Dynamics — Sistema OFS/OFS                              │
│  Documento gerado automaticamente                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Wireframe Textual — Relatório Mensal

```
┌─────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════╗ │
│ ║ [LOGO SD]              SISTEMA OFS/OFS     RELATÓRIO MENSAL  ║ │
│ ╚═══════════════════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════════════════  │
│                                                                   │
│  RELATÓRIO MENSAL DE MÉTRICAS                                     │
│  ─────────────────────────────────────                             │
│  Mês: Maio/2026  │  Período: 01/05/2026 a 31/05/2026              │
│  Contrato: Operação Security Dynamics                              │
│  Emitido por: Carlos Henrique Oliveira  │  13/05/2026 14:45        │
│                                                                   │
│  ═══════════ RESUMO DO MÊS ═══════════                             │
│                                                                   │
│  ┌──────────┬──────────┬──────────┬──────────┬────────────────┐  │
│  │Total Prog│Total Real│Aderência │Positivas │  Melhor Semana │  │
│  │          │          │  Mensal  │Negativas │  Semana Crítica│  │
│  ├──────────┼──────────┼──────────┼──────────┼────────────────┤  │
│  │  3.100   │  2.735   │  88.2%   │ 2.200 /  │ S17: 101.3% ✅│  │
│  │          │          │  🟡 ATEN │   535    │ S20:  86.0% ⚠ │  │
│  └──────────┴──────────┴──────────┴──────────┴────────────────┘  │
│                                                                   │
│  ═══════════ INDICADORES MENSAIS ═══════════                       │
│                                                                   │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐         │
│  │% Seguro  │% Desvio  │Média Sem.│Usuários  │Média OFS │         │
│  │  Mensal  │  Mensal  │Realizada │Ativos M. │/Usuário  │         │
│  ├──────────┼──────────┼──────────┼──────────┼──────────┤         │
│  │  80.4%   │  19.6%   │   684    │   9.5    │   72.0   │         │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘         │
│                                                                   │
│  ═══════════ EVOLUÇÃO SEMANAL DO MÊS ═══════════                   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  Semana │Program.│Realiz.│Posit.│Negat.│Ader.%│% Seg.│Sta  │   │
│  ├─────────┼────────┼───────┼──────┼──────┼──────┼──────┼─────┤   │
│  │ 18 (04/5)│  800  │  700  │ 580  │ 120  │ 87.5%│ 82.8%│ATEN │   │
│  │ 19 (11/5)│  750  │  690  │ 550  │ 140  │ 92.0%│ 79.7%│ATEN │   │
│  │ 20 (18/5)│  800  │  710  │ 585  │ 125  │ 88.8%│ 82.4%│ATEN │   │
│  │ 21 (25/5)│  750  │  635  │ 485  │ 150  │ 84.7%│ 76.4%│ATEN │   │
│  │TOTAL     │ 3.100 │ 2.735 │2.200 │ 535  │ 88.2%│ 80.4%│ATEN │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ═══════════ GRÁFICOS ═══════════                                  │
│                                                                   │
│  [Gráfico 1: Aderência por Semana — Linha]                         │
│  [Gráfico 2: Positivo x Negativo por Semana — Barras empilhadas]   │
│  [Gráfico 3: Programado x Realizado por Semana — Barras lado/lado] │
│  [Gráfico 4: Top Empresas Observadas — Barras horizontais]         │
│  [Gráfico 5: Top Usuários Geradores — Barras horizontais]          │
│                                                                   │
│  ═══════════════════════════════════════════════════════════════  │
│  Gerado em: 13/05/2026 14:45             │   Página 1 de 2       │
│  Security Dynamics — Sistema OFS/OFS                              │
│  Documento gerado automaticamente                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Wireframe Textual — Ranking por Empresa

```
┌─────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════╗ │
│ ║ [LOGO SD]              SISTEMA OFS/OFS    RANKING EMPRESAS   ║ │
│ ╚═══════════════════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════════════════  │
│                                                                   │
│  RANKING POR EMPRESA OBSERVADA                                     │
│  ─────────────────────────────────────                              │
│  Semana: 20/2026  │  11/05/2026 a 17/05/2026                       │
│  Ordenação: Maior volume de OFCs                                   │
│  Emitido por: Carlos Henrique Oliveira  │  13/05/2026 14:45        │
│                                                                   │
│  ═══════════ GRÁFICO ═══════════                                   │
│                                                                   │
│  [Barras horizontais: OFS por Empresa]                             │
│                                                                   │
│  ═══════════ TABELA DE RANKING ═══════════                         │
│                                                                   │
│  ┌────┬──────────────┬──────┬──────┬──────┬──────┬──────┬──────┐  │
│  │Pos.│ Empresa      │OFCs  │Posit.│Negat.│% Seg.│Part. │Status│  │
│  ├────┼──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤  │
│  │ 1  │Sec. Dynamics │  645 │  520 │  125 │ 80.6%│ 27.6%│ATEN  │  │
│  │ 2  │ERA           │  510 │  450 │   60 │ 88.2%│ 21.8%│OK    │  │
│  │ 3  │G4S           │  380 │  310 │   70 │ 81.6%│ 16.2%│ATEN  │  │
│  │ 4  │Sodexo        │  250 │  210 │   40 │ 84.0%│ 10.7%│ATEN  │  │
│  │ 5  │Conin         │  220 │  180 │   40 │ 81.8%│  9.4%│ATEN  │  │
│  │ 6  │Polo Norte    │  200 │  160 │   40 │ 80.0%│  8.5%│ATEN  │  │
│  │ 7  │FM            │  135 │  105 │   30 │ 77.8%│  5.8%│ALERT │  │
│  ├────┼──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤  │
│  │    │ TOTAL         │2.340 │1.935 │  405 │ 82.7%│ 100% │ATEN  │  │
│  └────┴──────────────┴──────┴──────┴──────┴──────┴──────┴──────┘  │
│                                                                   │
│  ═══════════════════════════════════════════════════════════════  │
│  Gerado em: 13/05/2026 14:45             │   Página 1 de 1       │
│  Security Dynamics — Sistema OFS/OFS                              │
│  Documento gerado automaticamente                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Wireframe Textual — Ranking por Usuário

```
┌─────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════╗ │
│ ║ [LOGO SD]              SISTEMA OFS/OFS    RANKING USUÁRIOS   ║ │
│ ╚═══════════════════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════════════════  │
│                                                                   │
│  RANKING POR USUÁRIO GERADOR                                       │
│  ─────────────────────────────────────                              │
│  Semana: 20/2026  │  11/05/2026 a 17/05/2026                       │
│  Contrato: Operação Security Dynamics                              │
│  Emitido por: Carlos Henrique Oliveira  │  13/05/2026 14:45        │
│                                                                   │
│  ═══════════ GRÁFICO ═══════════                                   │
│                                                                   │
│  [Barras horizontais: OFS por Usuário]                             │
│                                                                   │
│  ═══════════ TABELA DE RANKING ═══════════                         │
│                                                                   │
│  ┌────┬──────────┬──────┬──────┬──────┬──────┬──────┬──────────┐  │
│  │Pos.│ Usuário  │OFCs  │Posit.│Negat.│Média │% Seg.│Último Reg│  │
│  ├────┼──────────┼──────┼──────┼──────┼──────┼──────┼──────────┤  │
│  │ 1  │Carlos O. │   85 │   70 │   15 │  17.0│ 82.4%│17/05 16:3│  │
│  │ 2  │Ana Souza │   72 │   60 │   12 │  14.4│ 83.3%│17/05 15:1│  │
│  │ 3  │Pedro Lima│   58 │   48 │   10 │  11.6│ 82.8%│17/05 14:0│  │
│  │ 4  │Julia Melo│   45 │   38 │    7 │   9.0│ 84.4%│16/05 10:3│  │
│  │ 5  │Marcos R. │   42 │   32 │   10 │   8.4│ 76.2%│17/05 08:1│  │
│  │ 6  │Patrícia A│   38 │   35 │    3 │   7.6│ 92.1%│16/05 17:0│  │
│  │ 7  │Rafael C. │   0  │    0 │    0 │   0.0│   —  │   —      │  │
│  └────┴──────────┴──────┴──────┴──────┴──────┴──────┴──────────┘  │
│                                                                   │
│  ⚠ Rafael C.: usuário ativo sem registros na semana               │
│                                                                   │
│  ═══════════════════════════════════════════════════════════════  │
│  Gerado em: 13/05/2026 14:45             │   Página 1 de 1       │
│  Security Dynamics — Sistema OFS/OFS                              │
│  Documento gerado automaticamente                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Wireframe Textual — Histórico de Desvios

```
┌─────────────────────────────────────────────────────────────────┐
│ ╔═══════════════════════════════════════════════════════════════╗ │
│ ║ [LOGO SD]              SISTEMA OFS/OFS   HISTÓRICO DESVIOS   ║ │
│ ╚═══════════════════════════════════════════════════════════════╝ │
│ ═══════════════════════════════════════════════════════════════  │
│                                                                   │
│  HISTÓRICO DE DESVIOS (COMPORTAMENTOS NEGATIVOS/INSEGUROS)         │
│  ─────────────────────────────────────                              │
│  Período: 01/05/2026 a 17/05/2026                                   │
│  Filtros: Empresa: Security Dynamics | Contrato: Todos              │
│  Emitido por: Carlos Henrique Oliveira  │  13/05/2026 14:45        │
│                                                                   │
│  ═══════════ GRÁFICOS ═══════════                                  │
│                                                                   │
│  [Gráfico 1: Top Comportamentos Negativos — Barras horizontais]    │
│  [Gráfico 2: Desvios por Local — Pizza]                            │
│  [Gráfico 3: Desvios por Turno — Pizza]                            │
│  [Gráfico 4: Evolução dos Desvios — Linha]                         │
│                                                                   │
│  ═══════════ REGISTROS ═══════════                                 │
│                                                                   │
│  ┌──────┬──────────┬──────────┬──────┬──────────┬────────────────┐│
│  │OFS # │ Data     │Empresa   │Local │ Turno    │Comportamento   ││
│  ├──────┼──────────┼──────────┼──────┼──────────┼────────────────┤│
│  │ 1522 │13/05/2026│G4S       │Arm. B│Noturno   │Ausência de EPI ││
│  │ 1515 │12/05/2026│SD        │Arm. A│Diurno    │Postura incorr. ││
│  │ 1508 │12/05/2026│ERA       │Pátio │Misto     │Falta de sinal. ││
│  │ 1502 │11/05/2026│Polo Norte│Port. │ADM       │Excesso velocid.││
│  │ 1498 │11/05/2026│SD        │Arm. B│Noturno   │Falta de EPI    ││
│  └──────┴──────────┴──────────┴──────┴──────────┴────────────────┘│
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ TOTAL DE DESVIOS NO PERÍODO: 405                              │  │
│  │ % do total de registros: 17.3%                                 │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ═══════════════════════════════════════════════════════════════  │
│  Gerado em: 13/05/2026 14:45             │   Página 1 de 2       │
│  Security Dynamics — Sistema OFS/OFS                              │
│  Documento gerado automaticamente                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Lista de Gráficos e Especificações

### 8.1 Catálogo de Gráficos

| # | Nome | Tipo | Dados de Entrada | Agrupamento | Ordenação |
|---|------|------|------------------|-------------|-----------|
| 1 | Programado x Realizado | Barras lado a lado | programadas, realizadas | Por período | Fixo: Programado, Realizado |
| 2 | Positivo x Negativo | Rosca (Donut) | positivas, negativas | Por período | Fixo: Positivo, Negativo |
| 3 | OFS por Empresa | Barras horizontais | empresa, total | Por empresa_observada_id | Decrescente por total |
| 4 | OFS por Usuário | Barras horizontais | usuario, total | Por usuario_id | Decrescente por total |
| 5 | OFS por Turno | Pizza | turno, total | Por turno | Por nome do turno |
| 6 | Top Comportamentos | Barras horizontais | comportamento, contagem | Por comportamento_observado (texto) | Decrescente por contagem |
| 7 | Evolução Semanal | Linha | semana, aderencia_percentual | Por semana (últimas 8-12) | Crescente por semana |
| 8 | Evolução Mensal | Linha | mes, aderencia_percentual | Por mês (últimos 6-12) | Crescente por mês |
| 9 | Desvios por Local | Barras horizontais | local, total_desvios | Por local_id | Decrescente por total |
| 10 | Desvios por Turno | Pizza | turno, total_desvios | Por turno | Por nome do turno |

### 8.2 Ficha Técnica de Cada Gráfico

#### GRÁFICO 1: Programado x Realizado

```
Tipo:           Barras lado a lado
Dados:          [ {label: "Programado", value: 750}, {label: "Realizado", value: 645} ]
Query SQL:      SELECT 
                  (SELECT COALESCE(SUM(meta_ofc_programada), 0) 
                   FROM metas_semanais WHERE contrato_id = ? AND ano = ? AND semana = ?) AS programadas,
                  (SELECT COUNT(*) FROM ofc_registros 
                   WHERE contrato_id = ? AND semana = ? AND ano = ? 
                   AND status_registro != 'Cancelado' AND deleted = FALSE) AS realizadas
Cores:          Programado: #3498db (azul) | Realizado: #22C55E (verde) OU #f39c12 (laranja)
Altura:         200px (frontend) / 5cm (PDF)
Largura:        100% do container
Anotações:      Valor numérico no topo de cada barra
Posição PDF:    Página 1, metade superior
Tratamento:     Se programado = 0: mostrar "Sem meta cadastrada"
```

#### GRÁFICO 2: Positivo x Negativo

```
Tipo:           Rosca (Donut) — pie chart com centro vazio
Dados:          [ {label: "Positivo/Seguro", value: 520}, {label: "Negativo/Inseguro", value: 125} ]
Fórmula:        positivas = COUNT WHERE tipo = 'Positivo'
                negativas = COUNT WHERE tipo = 'Negativo'
Cores:          Positivo: #22C55E | Negativo: #EF4444
Centro:         Total de OFCs (645) em destaque
Altura:         200px / 6cm
Largura:        100%
Posição PDF:    Página 1, ao lado do Gráfico 1
Tratamento:     Se total = 0: gráfico cinza com "Sem dados"
```

#### GRÁFICO 3: OFS por Empresa

```
Tipo:           Barras horizontais
Dados:          [ {empresa: "Security Dynamics", total: 645}, ... ]
Query:          SELECT e.nome, COUNT(*) as total
                FROM ofc_registros o
                JOIN empresas e ON o.empresa_observada_id = e.id
                WHERE o.semana = ? AND o.ano = ? AND o.status_registro != 'Cancelado'
                GROUP BY e.nome ORDER BY total DESC
                LIMIT 10
Cores:          Degradê de vermelho (#CC0000 → #FEE2E2) ou azul corporativo
Ordenação:      Decrescente por total
Altura:         Dinâmica: 1cm por barra + 2cm margem
Posição PDF:    Página 1 (se couber) ou Página 2
Tratamento:     Se 0 resultados: "Nenhum registro no período"
```

#### GRÁFICO 4: OFS por Usuário

```
Tipo:           Barras horizontais
Dados:          [ {usuario: "Carlos Oliveira", total: 85}, ... ]
Query:          SELECT u.nome, COUNT(*) as total
                FROM ofc_registros o
                JOIN usuarios u ON o.usuario_id = u.id
                WHERE o.contrato_id = ? AND o.semana = ? AND o.ano = ?
                AND o.status_registro != 'Cancelado'
                GROUP BY u.nome ORDER BY total DESC
                LIMIT 15
Cores:          #CC0000 (vermelho institucional)
Posição PDF:    Página 2, ao lado do Gráfico 3
```

#### GRÁFICO 5: OFS por Turno

```
Tipo:           Pizza (pie chart)
Dados:          [ {turno: "Diurno", total: 280}, ... ]
Query:          SELECT turno, COUNT(*) as total
                FROM ofc_registros
                WHERE contrato_id = ? AND semana = ? AND ano = ?
                AND status_registro != 'Cancelado'
                GROUP BY turno ORDER BY turno
Cores:          Paleta com 6 cores: #CC0000, #22C55E, #3498db, #f39c12, #9b59b6, #1abc9c
Posição PDF:    Página 2
```

#### GRÁFICO 6: Top Comportamentos

```
Tipo:           Barras horizontais
Dados:          [ {comportamento: "Uso correto de EPI", count: 45}, ... ]
Query:          SELECT comportamento_observado, COUNT(*) as contagem
                FROM ofc_registros
                WHERE contrato_id = ? AND semana = ? AND ano = ?
                AND status_registro != 'Cancelado'
                GROUP BY comportamento_observado
                ORDER BY contagem DESC LIMIT 10
Cores:          Positivos: #22C55E | Negativos: #EF4444 (identificar por tipo)
Labels:         Truncar em 50 caracteres com "..."
Posição PDF:    Página 2 ou 3
Tratamento:     Agrupar textos similares (normalização simples)
```

#### GRÁFICO 7: Evolução Semanal

```
Tipo:           Linha
Dados:          [ {semana: "S13", aderencia: 96.0, realizadas: 720, programadas: 750}, ... ]
Query:          Para cada semana: calcular aderencia_percentual com fórmula padrão
Período:        Últimas 8 semanas (configurável até 12)
Cores:          Linha principal: #CC0000 (2px)
                Linha Meta 100%: #22C55E tracejada (1px)
                Linha Alerta 80%: #EF4444 tracejada (1px)
Eixo Y:         0% a 120%
Marcadores:     Círculo (●) em cada ponto
Posição PDF:    Página 2 ou 3, largura total
Tratamento:     Se < 4 semanas de dados: mostrar nota "Dados insuficientes para tendência"
```

#### GRÁFICO 8: Evolução Mensal

```
Tipo:           Linha
Dados:          [ {mes: "Jan/26", aderencia: 92.0}, {mes: "Fev/26", aderencia: 88.5}, ... ]
Query:          Similar à evolução semanal, agrupado por mês
Período:        Últimos 6 a 12 meses
Cores e eixos: Idem Gráfico 7
Posição PDF:    Relatório mensal, página 2
```

#### GRÁFICO 9: Desvios por Local

```
Tipo:           Barras horizontais
Dados:          [ {local: "Armazém B", total: 45}, ... ]
Query:          SELECT l.nome, COUNT(*) as total
                FROM ofc_registros o
                JOIN locais l ON o.local_id = l.id
                WHERE o.tipo_observacao = 'Negativo'
                AND o.data_registro BETWEEN ? AND ?
                GROUP BY l.nome ORDER BY total DESC
Cores:          #EF4444 (vermelho)
Posição PDF:    Relatório de Desvios, página 1
```

#### GRÁFICO 10: Desvios por Turno

```
Tipo:           Pizza
Dados:          Agrupado por turno, apenas registros Negativos
Query:          SELECT turno, COUNT(*) as total
                FROM ofc_registros
                WHERE tipo_observacao = 'Negativo'
                AND data_registro BETWEEN ? AND ?
                GROUP BY turno
Cores:          Tons de vermelho e laranja
```

---

## 9. Fórmulas dos Indicadores

### 9.1 Fórmulas Base (aplicadas em todos os relatórios)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. OFS PROGRAMADAS                                                   │
│    = pessoas_ativas × meta_ofc_por_pessoa                            │
│    Fonte: tabela metas_semanais (calculado por trigger)              │
│                                                                      │
│ 2. OFS REALIZADAS                                                    │
│    = COUNT(*) FROM ofc_registros                                     │
│      WHERE semana = ? AND ano = ? AND contrato_id = ?                │
│      AND status_registro != 'Cancelado'                              │
│                                                                      │
│ 3. ADERÊNCIA %                                                       │
│    = (OFC_REALIZADAS ÷ OFC_PROGRAMADAS) × 100                        │
│    Arredondamento: 1 casa decimal                                    │
│    Se OFC_PROGRAMADAS = 0: aderencia = 0                             │
│                                                                      │
│ 4. POSITIVAS                                                         │
│    = COUNT(*) WHERE tipo_observacao = 'Positivo'                     │
│                                                                      │
│ 5. NEGATIVAS                                                         │
│    = COUNT(*) WHERE tipo_observacao = 'Negativo'                     │
│                                                                      │
│ 6. % SEGURO                                                          │
│    = (POSITIVAS ÷ OFC_REALIZADAS) × 100                              │
│    Se OFC_REALIZADAS = 0: %_SEGURO = 0                               │
│                                                                      │
│ 7. % DESVIO                                                          │
│    = (NEGATIVAS ÷ OFC_REALIZADAS) × 100                              │
│    Se OFC_REALIZADAS = 0: %_DESVIO = 0                               │
│    Ou: %_DESVIO = 100 − %_SEGURO                                     │
│                                                                      │
│ 8. USUÁRIOS ATIVOS                                                   │
│    = COUNT(DISTINCT usuario_id) FROM ofc_registros                   │
│      WHERE semana = ? AND ano = ? AND contrato_id = ?                │
│                                                                      │
│ 9. MÉDIA OFS POR USUÁRIO                                             │
│    = OFC_REALIZADAS ÷ USUARIOS_ATIVOS                                │
│    Se USUARIOS_ATIVOS = 0: MEDIA = 0                                 │
│                                                                      │
│ 10. PARTICIPAÇÃO % (ranking empresa)                                  │
│     = (OFC_REALIZADAS_EMPRESA ÷ OFC_REALIZADAS_TOTAL) × 100          │
└─────────────────────────────────────────────────────────────────────┘
```

### 9.2 Cálculo de Status

```
┌──────────────────────────────────────────────────────┐
│ STATUS =                                             │
│   IF aderencia_percentual >= 100:                    │
│     "OK"          Cor: 🟢 Verde  (#22C55E)           │
│   ELSE IF aderencia_percentual >= 80:                │
│     "ATENÇÃO"     Cor: 🟡 Amarelo (#EAB308)          │
│   ELSE:                                              │
│     "ALERTA"      Cor: 🔴 Vermelho (#EF4444)         │
└──────────────────────────────────────────────────────┘
```

### 9.3 SQL de Métricas Semanais (Query Completa)

```sql
-- Métricas da Semana — Query principal
WITH 
meta AS (
    SELECT pessoas_ativas, meta_ofc_por_pessoa, meta_ofc_programada, usuarios_ativos
    FROM metas_semanais
    WHERE contrato_id = :contrato_id AND ano = :ano AND semana = :semana
    LIMIT 1
),
realizadas AS (
    SELECT 
        COUNT(*) AS total_realizadas,
        COUNT(*) FILTER (WHERE tipo_observacao = 'Positivo') AS positivas,
        COUNT(*) FILTER (WHERE tipo_observacao = 'Negativo') AS negativas,
        COUNT(DISTINCT usuario_id) AS usuarios_ativos
    FROM ofc_registros
    WHERE contrato_id = :contrato_id 
      AND ano = :ano 
      AND semana = :semana
      AND status_registro != 'Cancelado'
)
SELECT 
    m.pessoas_ativas,
    m.meta_ofc_por_pessoa,
    m.meta_ofc_programada AS ofc_programadas,
    r.total_realizadas AS ofc_realizadas,
    ROUND((r.total_realizadas::numeric / NULLIF(m.meta_ofc_programada, 0)) * 100, 1) AS aderencia_percentual,
    r.positivas,
    r.negativas,
    ROUND((r.positivas::numeric / NULLIF(r.total_realizadas, 0)) * 100, 1) AS percentual_seguro,
    ROUND((r.negativas::numeric / NULLIF(r.total_realizadas, 0)) * 100, 1) AS percentual_desvio,
    r.usuarios_ativos,
    ROUND((r.total_realizadas::numeric / NULLIF(r.usuarios_ativos, 0)), 1) AS media_ofc_por_usuario
FROM meta m, realizadas r;
```

---

## 10. Regras de Exportação

### 10.1 Formatos Disponíveis

| Formato | Relatórios Permitidos | Perfil Mínimo |
|---------|----------------------|:---:|
| **PDF** | Individual, Semanal, Mensal, Ranking Empresa, Ranking Usuário, Desvios | Observador (individual) / Gestor (demais) |
| **Impressão** | Qualquer PDF gerado | Todos com acesso ao relatório |

### 10.2 Fluxo de Exportação

```
1. Usuário acessa tela de Relatórios (ou Visualizar OFS para individual)
2. Seleciona tipo de relatório
3. Define parâmetros (período, empresa, contrato, etc.)
4. Clica [GERAR PDF]
5. Frontend mostra: "Gerando relatório..." (spinner)
6. Backend:
   a. Recebe requisição POST /api/relatorios/gerar
   b. Valida parâmetros e permissões
   c. Busca dados no banco
   d. Gera gráficos PNG (chart_service.py / matplotlib)
   e. Renderiza template HTML (Jinja2)
   f. Converte HTML → PDF (WeasyPrint)
   g. Salva PDF em /app/reports/
   h. Registra na tabela relatorios_gerados
   i. Registra auditoria (GERAR_PDF)
   j. Retorna URL de download
7. Frontend inicia download automaticamente
8. Toast: "PDF gerado com sucesso!"
```

### 10.3 Geração via API

```
POST /api/relatorios/gerar
Headers: Authorization: Bearer <jwt>

Body:
{
  "tipo": "individual",           // individual | semanal | mensal | ranking_empresas | ranking_usuarios | desvios
  "parametros": {
    "ofc_id": "uuid",             // apenas para tipo=individual
    "ano": 2026,                  // obrigatório para todos exceto individual
    "semana": 20,                 // obrigatório para semanal
    "mes": 5,                     // obrigatório para mensal
    "contrato_id": 1,
    "empresa_id": null,
    "turno": null,
    "usuario_id": null,
    "data_inicio": "2026-05-01",  // para desvios e relatórios customizados
    "data_fim": "2026-05-17"
  }
}

Response 202:
{
  "sucesso": true,
  "relatorio_id": "uuid",
  "status": "concluido",
  "download_url": "/api/relatorios/uuid/download",
  "nome_arquivo": "METRICAS_SEMANA_2026_20.pdf",
  "tamanho_bytes": 245760,
  "gerado_em": "2026-05-13T14:45:00-03:00"
}
```

### 10.4 Regras de Negócio da Exportação

| Regra | Descrição |
|-------|-----------|
| Permissão | Observador: apenas PDF individual de seus registros. Supervisor+: PDFs do contrato. Gestor+: todos os PDFs |
| Auditoria | Toda geração registrada em auditoria com: usuário, tipo, parâmetros, IP |
| Limite | Máximo 1 PDF por requisição. Sem geração em lote no MVP |
| Timeout | 60 segundos para geração. Se exceder, retornar erro 504 |
| Retenção | PDFs armazenados por 90 dias. Admin pode excluir antes |
| Download | Acesso autenticado. PDFs não são públicos |

---

## 11. Padrão de Nomes de Arquivos

### 11.1 Convenção

```
Formato: <TIPO>_<IDENTIFICADOR>_<DATA>.pdf

Regras:
- TIPO: maiúsculo, sem espaços
- IDENTIFICADOR: varia por tipo de relatório
- DATA: AAAAMMDD (8 dígitos)
- Sem caracteres especiais (apenas underline)
- Extensão: .pdf (minúsculo)
```

### 11.2 Padrão por Tipo

| Tipo de Relatório | Nome do Arquivo | Exemplo |
|-------------------|-----------------|---------|
| Individual OFS | `OFC_INDIVIDUAL_1523_20260513.pdf` | Código OFS + data geração |
| Métricas Semanal | `METRICAS_SEMANA_2026_20_20260513.pdf` | Ano + Semana + data geração |
| Métricas Mensal | `RELATORIO_MENSAL_2026_05_20260513.pdf` | Ano + Mês + data geração |
| Ranking Empresas | `RANKING_EMPRESAS_2026_20_20260513.pdf` | Ano + Semana + data geração |
| Ranking Usuários | `RANKING_USUARIOS_2026_20_20260513.pdf` | Ano + Semana + data geração |
| Histórico Desvios | `DESVIOS_20260501_20260517_20260513.pdf` | Data início + fim + geração |

### 11.3 Implementação

```python
from datetime import datetime

def gerar_nome_arquivo(tipo: str, parametros: dict) -> str:
    hoje = datetime.now().strftime("%Y%m%d")
    
    if tipo == "individual":
        return f"OFC_INDIVIDUAL_{parametros['codigo']}_{hoje}.pdf"
    
    elif tipo == "semanal":
        return f"METRICAS_SEMANA_{parametros['ano']}_{parametros['semana']}_{hoje}.pdf"
    
    elif tipo == "mensal":
        return f"RELATORIO_MENSAL_{parametros['ano']}_{parametros['mes']:02d}_{hoje}.pdf"
    
    elif tipo == "ranking_empresas":
        return f"RANKING_EMPRESAS_{parametros['ano']}_{parametros['semana']}_{hoje}.pdf"
    
    elif tipo == "ranking_usuarios":
        return f"RANKING_USUARIOS_{parametros['ano']}_{parametros['semana']}_{hoje}.pdf"
    
    elif tipo == "desvios":
        return f"DESVIOS_{parametros['data_inicio'].replace('-','')}_{parametros['data_fim'].replace('-','')}_{hoje}.pdf"
    
    else:
        return f"RELATORIO_{tipo}_{hoje}.pdf"
```

---

## 12. Estratégia para Geração Local de PDF

### 12.1 Stack Recomendada

| Stack | Biblioteca | Justificativa |
|-------|-----------|---------------|
| **FastAPI (Python)** | **WeasyPrint 61+** | ✅ Melhor opção. HTML/CSS → PDF sem browser. Suporta @page, cabeçalhos fixos, rodapés, CSS Paged Media. Empacotamento offline via `pip download`. |
| | ReportLab 4+ | ✅ Complementar. Geração programática de PDF quando precisão milimétrica é necessária. |
| | matplotlib 3.8+ | ✅ Gráficos PNG para embedar nos PDFs. 100% offline. |
| | Jinja2 3.x | ✅ Templates HTML com variáveis, loops, condicionais. |
| **Node.js/NestJS** | Puppeteer | ❌ Requer Chromium (~300MB). Overkill para intranet. Difícil empacotar offline. |
| | jsPDF | ⚠️ Limitado. Sem suporte a CSS Paged Media. Qualidade inferior para relatórios corporativos. |
| | pdfkit/wkhtmltopdf | ⚠️ Depende de wkhtmltopdf (binário externo). Suporte limitado a CSS moderno. |

**Decisão final: FastAPI + WeasyPrint + matplotlib + Jinja2.**

### 12.2 Empacotamento Offline

```dockerfile
# Dockerfile multi-stage — backend
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip download -r requirements.txt -d /offline-packages

FROM python:3.12-slim
WORKDIR /app
# Dependências de sistema para WeasyPrint (fontes, Cairo, Pango)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 \
    libffi-dev shared-mime-info fonts-dejavu-core fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /offline-packages /offline-packages
COPY requirements.txt .
RUN pip install --no-index --find-links /offline-packages -r requirements.txt

# Fontes Inter (locais)
COPY static/fonts/ /usr/share/fonts/truetype/inter/
RUN fc-cache -fv

COPY . .
USER appuser
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 12.3 Pipeline de Geração

```python
# services/report_service.py — orquestrador

async def gerar_relatorio_pdf(
    db: AsyncSession,
    tipo: str,
    parametros: dict,
    usuario: Usuario
) -> Report:
    """
    Pipeline completo de geração de PDF:
    1. Busca dados no banco
    2. Gera gráficos PNG
    3. Renderiza template HTML
    4. Converte para PDF com WeasyPrint
    5. Salva arquivo e registra no banco
    """
    
    # 1. Busca dados
    dados = await coletar_dados_relatorio(db, tipo, parametros)
    
    # 2. Gera gráficos (se aplicável)
    graficos = {}
    if tipo in ('semanal', 'mensal', 'ranking_empresas', 'ranking_usuarios', 'desvios'):
        graficos = await gerar_graficos_relatorio(tipo, dados)
    
    # 3. Renderiza template
    template_name = f"{tipo}.html"
    html_str = await renderizar_template(template_name, {
        **dados,
        **graficos,  # PNGs em base64
        'parametros': parametros,
        'usuario': usuario,
        'data_geracao': datetime.now(),
    })
    
    # 4. Converte HTML → PDF
    pdf_bytes = HTML(string=html_str).write_pdf()
    
    # 5. Salva e registra
    nome_arquivo = gerar_nome_arquivo(tipo, {**parametros, **dados})
    caminho = Path(settings.REPORTS_DIR) / nome_arquivo
    caminho.write_bytes(pdf_bytes)
    
    report = Report(
        tipo=tipo,
        parametros=parametros,
        arquivo_path=str(caminho),
        arquivo_tamanho=len(pdf_bytes),
        usuario_id=usuario.id,
        nome_arquivo=nome_arquivo,
    )
    db.add(report)
    await db.commit()
    
    # Auditoria
    await registrar_auditoria(db, usuario.id, "GERAR_PDF", "relatorios",
        dados_novos={"tipo": tipo, "arquivo": nome_arquivo})
    
    return report
```

### 12.4 Estrutura de Templates Jinja2

```
backend/templates/reports/
├── _base.html              # Template base com @page, header, footer CSS
├── individual.html         # Relatório individual OFS
├── semanal.html            # Métricas da semana
├── mensal.html             # Relatório mensal
├── ranking_empresas.html   # Ranking por empresa
├── ranking_usuarios.html   # Ranking por usuário
└── desvios.html            # Histórico de desvios
```

---

## 13. Estratégia para Inclusão do Logotipo

### 13.1 Especificação do Logo

```
Arquivo:        security-dynamics.png (ou .svg)
Formato:        PNG com transparência (recomendado)
Resolução:      300 DPI (para impressão nítida)
Dimensões:      180px × 60px (proporção 3:1)
                 -> 15.24mm × 5.08mm efetivo no PDF
Localização:    backend/static/logos/security-dynamics.png

Alternativo:    SVG (escalável, mais leve)
                backend/static/logos/security-dynamics.svg
```

### 13.2 Inclusão no Template HTML (WeasyPrint)

```html
<!-- _base.html — Cabeçalho -->
<div id="pageHeader">
    <img src="file:///app/static/logos/security-dynamics.png" 
         alt="Security Dynamics"
         style="height: 20mm; width: auto;" />
    <div class="header-right">
        <div class="system-name">SISTEMA DE FEEDBACK COMPORTAMENTAL</div>
        <div class="system-sub">OFS / OFS</div>
    </div>
    <div class="report-title">{{ titulo_relatorio }}</div>
</div>
```

### 13.3 Alternativa: Logo em Base64 (evita path absoluto)

```python
import base64
from pathlib import Path

def logo_base64():
    """Converte logo para base64 para embed direto no HTML."""
    logo_path = Path(__file__).parent.parent / "static" / "logos" / "security-dynamics.png"
    with open(logo_path, "rb") as f:
        return base64.b64encode(f.read()).decode()

# No contexto do template:
context["logo_base64"] = logo_base64()
```

```html
<img src="data:image/png;base64,{{ logo_base64 }}" 
     alt="Security Dynamics"
     style="height: 20mm;" />
```

### 13.4 Regras de Posicionamento

| Elemento | Posição | Alinhamento |
|----------|---------|-------------|
| Logo | Canto superior esquerdo do cabeçalho | Esquerda |
| Nome do sistema | Ao lado direito do logo | Esquerda |
| Título do relatório | Canto superior direito | Direita |
| Todos no header | Mesma linha horizontal | Distribuído |

---

## 14. Estratégia para Gráficos no PDF

### 14.1 Pipeline de Geração de Gráficos

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────────┐
│  Dados do    │────▶│  chart_service  │────▶│  PNG em memória  │
│  banco       │     │  (matplotlib)   │     │  (BytesIO)       │
│  (query)     │     │                 │     │                  │
└──────────────┘     │  - Barras       │     └────────┬─────────┘
                     │  - Linha        │              │
                     │  - Pizza/Rosca  │              ▼
                     │  - Horizontal   │     ┌──────────────────┐
                     └─────────────────┘     │  base64 encode   │
                                             └────────┬─────────┘
                                                      │
                                                      ▼
                                             ┌──────────────────┐
                                             │  Template HTML   │
                                             │  <img src="data: │
                                             │   image/png;     │
                                             │   base64,...">   │
                                             └────────┬─────────┘
                                                      │
                                                      ▼
                                             ┌──────────────────┐
                                             │  WeasyPrint      │
                                             │  HTML → PDF      │
                                             └──────────────────┘
```

### 14.2 Configuração do matplotlib para PDF

```python
# chart_service.py

import matplotlib
matplotlib.use('Agg')  # Backend não-interativo (sem GUI)
import matplotlib.pyplot as plt
import io
import base64

# Configuração global de estilo
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.size': 10,
    'axes.titlesize': 12,
    'axes.labelsize': 10,
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'savefig.dpi': 150,          # Alta resolução para PDF
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.1,
})

# Paleta corporativa
CORES = {
    'vermelho':  '#CC0000',
    'verde':     '#22C55E',
    'azul':      '#3498db',
    'laranja':   '#f39c12',
    'amarelo':   '#EAB308',
    'roxo':      '#9b59b6',
    'ciano':     '#1abc9c',
    'cinza':     '#95a5a6',
}

def gerar_grafico_barras_duplas(labels, valores1, valores2, 
                                 titulo, legenda1, legenda2) -> str:
    """Gera gráfico de barras lado a lado e retorna base64."""
    fig, ax = plt.subplots(figsize=(8, 4))
    
    x = range(len(labels))
    width = 0.35
    bars1 = ax.bar([i - width/2 for i in x], valores1, width, 
                    label=legenda1, color=CORES['azul'])
    bars2 = ax.bar([i + width/2 for i in x], valores2, width, 
                    label=legenda2, color=CORES['verde'])
    
    # Anotações nos topos
    for bar in bars1:
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
                str(int(bar.get_height())), ha='center', fontsize=9, fontweight='bold')
    for bar in bars2:
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
                str(int(bar.get_height())), ha='center', fontsize=9, fontweight='bold')
    
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_title(titulo)
    ax.legend(loc='upper right', frameon=False)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    
    return _fig_para_base64(fig)

def gerar_grafico_rosca(labels, valores, titulo, cores) -> str:
    """Gera gráfico de rosca (donut)."""
    fig, ax = plt.subplots(figsize=(6, 6))
    wedges, texts, autotexts = ax.pie(
        valores, labels=labels, colors=cores,
        autopct='%1.1f%%', startangle=90,
        pctdistance=0.85,
        wedgeprops=dict(width=0.4, edgecolor='white')
    )
    ax.set_title(titulo, pad=15)
    
    return _fig_para_base64(fig)

def gerar_grafico_linha(x_labels, y_valores, titulo, 
                         linha_meta=100, linha_alerta=80) -> str:
    """Gera gráfico de linha com referências de meta e alerta."""
    fig, ax = plt.subplots(figsize=(10, 4))
    
    ax.plot(x_labels, y_valores, marker='o', color=CORES['vermelho'],
            linewidth=2, markersize=6, label='Aderência %')
    ax.axhline(y=linha_meta, color=CORES['verde'], linestyle='--', 
               linewidth=1, alpha=0.7, label=f'Meta {linha_meta}%')
    ax.axhline(y=linha_alerta, color=CORES['amarelo'], linestyle='--',
               linewidth=1, alpha=0.7, label=f'Alerta {linha_alerta}%')
    
    ax.set_ylim(0, max(max(y_valores) * 1.1, linha_meta * 1.1))
    ax.set_title(titulo)
    ax.legend(loc='lower left', frameon=False)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.3)
    
    return _fig_para_base64(fig)

def _fig_para_base64(fig) -> str:
    """Converte figura matplotlib para string base64."""
    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    buf.seek(0)
    b64 = base64.b64encode(buf.read()).decode('utf-8')
    plt.close(fig)
    return f"data:image/png;base64,{b64}"
```

### 14.3 Tratamento de Erros nos Gráficos

```python
def gerar_grafico_seguro(func, *args, **kwargs) -> str:
    """Wrapper que retorna placeholder em caso de erro."""
    try:
        return func(*args, **kwargs)
    except Exception as e:
        logger.error(f"Erro ao gerar gráfico: {e}")
        return _gerar_placeholder("Erro ao gerar gráfico")

def _gerar_placeholder(mensagem: str) -> str:
    """Gera imagem placeholder com mensagem de erro."""
    fig, ax = plt.subplots(figsize=(6, 4))
    ax.text(0.5, 0.5, mensagem, ha='center', va='center', 
            fontsize=14, color='#9CA3AF', transform=ax.transAxes)
    ax.set_xticks([])
    ax.set_yticks([])
    return _fig_para_base64(fig)
```

---

## 15. Regras de Auditoria para Exportações

### 15.1 Eventos Registrados

| Ação | Entidade | Dados Registrados | Severidade |
|------|----------|-------------------|:---:|
| `GERAR_PDF` | `relatorios` | `{ tipo, parametros, nome_arquivo, tamanho }` | INFO |
| `EXPORTAR_RELATORIO` | `relatorios` | `{ formato, tipo, filtros_aplicados }` | INFO |
| `DOWNLOAD_PDF` | `relatorios` | `{ relatorio_id, nome_arquivo }` | INFO |

### 15.2 Implementação

```python
@router.post("/api/relatorios/gerar")
async def gerar_relatorio(
    body: RelatorioRequest,
    db: AsyncSession = Depends(get_db),
    usuario: Usuario = Depends(get_current_user),
    request: Request = None
):
    # 1. Validar permissão
    await verificar_permissao_relatorio(usuario, body.tipo, body.parametros)
    
    # 2. Gerar PDF
    report = await gerar_relatorio_pdf(db, body.tipo, body.parametros, usuario)
    
    # 3. Auditoria
    await registrar_auditoria(
        db,
        usuario_id=usuario.id,
        acao="GERAR_PDF",
        entidade="relatorios",
        entidade_id=str(report.id),
        dados_novos={
            "tipo": report.tipo,
            "parametros": body.parametros,
            "nome_arquivo": report.nome_arquivo,
            "tamanho_bytes": report.arquivo_tamanho,
        },
        ip_origem=request.client.host if request else None
    )
    
    return {
        "sucesso": True,
        "relatorio_id": str(report.id),
        "download_url": f"/api/relatorios/{report.id}/download",
        "nome_arquivo": report.nome_arquivo,
        "tamanho_bytes": report.arquivo_tamanho,
    }

@router.get("/api/relatorios/{id}/download")
async def download_relatorio(
    id: UUID,
    db: AsyncSession = Depends(get_db),
    usuario: Usuario = Depends(get_current_user),
    request: Request = None
):
    report = await db.get(Report, id)
    if not report:
        raise HTTPException(404, "Relatório não encontrado")
    
    # Auditoria de download
    await registrar_auditoria(
        db, usuario.id, "DOWNLOAD_PDF", "relatorios", str(id),
        dados_novos={"nome_arquivo": report.nome_arquivo},
        ip_origem=request.client.host if request else None
    )
    
    return FileResponse(
        report.arquivo_path,
        media_type="application/pdf",
        filename=report.nome_arquivo,
        headers={"Content-Disposition": f'attachment; filename="{report.nome_arquivo}"'}
    )
```

---

## 16. Critérios de Aceite dos Relatórios

### 16.1 Relatório Individual OFS/OFS

- [ ] PDF gerado em formato A4 retrato
- [ ] Logo Security Dynamics visível no cabeçalho de todas as páginas
- [ ] Nº OFS/OFS em destaque no topo
- [ ] Todos os campos obrigatórios presentes: código, data, hora, usuário gerador, login, email, empresa usuário, contrato, empresa observada, nome observado, atividade, local, turno, tipo, comportamento, observação
- [ ] Tipo "Positivo" com indicador visual verde (✅ ou barra verde)
- [ ] Tipo "Negativo" com indicador visual vermelho (❌ ou barra vermelha)
- [ ] Status "Cancelado" com destaque visual e motivo do cancelamento
- [ ] Histórico de edições visível (se houver)
- [ ] Rodapé com: data/hora geração, página X/Y, nome da empresa, "Documento gerado automaticamente"
- [ ] Fonte Inter carregada (sem fallback para fonte do sistema)
- [ ] Margens consistentes (20mm)
- [ ] Download funciona com nome correto: `OFC_INDIVIDUAL_<codigo>_<data>.pdf`

### 16.2 Relatório MÉTRICAS DA SEMANA

- [ ] PDF gerado em formato A4 retrato (2-3 páginas)
- [ ] Cabeçalho e rodapé em todas as páginas
- [ ] Seção "INDICADORES PRINCIPAIS" com 3 cards: Aderência, % Seguro, Status
- [ ] 10 indicadores detalhados visíveis
- [ ] Status colorido: verde (OK ≥100%), amarelo (ATENÇÃO 80-99%), vermelho (ALERTA <80%)
- [ ] 5 gráficos gerados: Programado x Realizado, Positivo x Negativo, OFS por Empresa, OFS por Usuário, Evolução Semanal
- [ ] Tabela consolidada com todas as empresas/contratos
- [ ] Filtros aplicados visíveis no topo (semana, período, contrato, empresa)
- [ ] Nome do usuário emissor e data de geração
- [ ] Quebra de página correta (tabela não cortada no meio, gráfico não dividido)
- [ ] Download: `METRICAS_SEMANA_<ano>_<semana>.pdf`

### 16.3 Relatório Mensal

- [ ] PDF A4 retrato (2-3 páginas)
- [ ] Resumo do mês com totais e médias
- [ ] Tabela semana a semana com indicadores
- [ ] Melhor semana e semana crítica destacadas
- [ ] Gráfico de evolução semanal do mês (linha)
- [ ] Download: `RELATORIO_MENSAL_<ano>_<mes>.pdf`

### 16.4 Geral (todos os relatórios)

- [ ] Geração local, sem requisição externa (internet/CDN)
- [ ] Fonte Inter local (sem Google Fonts)
- [ ] Logo carregado de arquivo local (sem URL externa)
- [ ] Gráficos gerados localmente (matplotlib)
- [ ] Tempo de geração < 30 segundos para relatórios com até 8 semanas de dados
- [ ] PDF visualmente correto em leitores: Adobe Acrobat, Chrome PDF Viewer, Edge PDF Viewer
- [ ] Impressão fiel ao visualizado em tela
- [ ] Auditoria registrada para cada geração e download
- [ ] Download só funciona para usuário autenticado (não público)
- [ ] Nome do arquivo segue convenção definida
- [ ] Relatório funcional em desktop, tablet e celular (PDF responsivo não se aplica; o PDF é tamanho fixo A4, mas deve ser legível ao fazer zoom)

### 16.5 Performance

- [ ] Geração de PDF individual: < 5 segundos
- [ ] Geração de PDF semanal (com 5 gráficos): < 30 segundos
- [ ] Geração de PDF mensal: < 30 segundos
- [ ] Download inicia em < 2 segundos após geração
- [ ] Sistema permanece responsivo durante geração (async)

---

**Documento gerado em 13/05/2026.**
