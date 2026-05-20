# ESPECIFICAÇÃO TELAS CORE — MÓDULO OFS/OFS

**Projeto:** Sistema OFS/OFS — Security Dynamics  
**Stack:** React 18 + Vite + TypeScript + Tailwind CSS 3.4 + Lucide React  
**Ambiente:** Intranet, offline-first (sem CDNs externas)  
**Data:** 13/05/2026  

---

## SUMÁRIO

1. [WIREFRAME — TELA NOVA OFS/OFS](#1-wireframe--tela-nova-ofcofs)
2. [WIREFRAME — TELA CONSULTA](#2-wireframe--tela-consulta)
3. [WIREFRAME — TELA VISUALIZAÇÃO](#3-wireframe--tela-visualizao)
4. [COMPONENTES REACT](#4-componentes-react)
5. [REGRAS DE VISIBILIDADE](#5-regras-de-visibilidade)
6. [RESPONSIVIDADE](#6-responsividade)
7. [FLUXO DE INTERAÇÃO](#7-fluxo-de-interao)

---

## 1. WIREFRAME — TELA NOVA OFS/OFS

### 1.1 Estado Inicial (Desktop 1280px)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ┌────────┐  ┌───────────────────────────────────────────────────────────────┐│
│ │ ☰ MENU │  │ ← VOLTAR            NOVA OFS/OFS              ⌨ Ctrl+S Salvar ││
│ └────────┘  └───────────────────────────────────────────────────────────────┘│
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ DADOS AUTOMÁTICOS                                                    │    │
│  │                                                                       │    │
│  │ ┌─────────────────────┐  ┌─────────────────┐  ┌──────────────────┐   │    │
│  │ │ Código              │  │ Data            │  │ Hora             │   │    │
│  │ │ ┌─────────────────┐ │  │ ┌─────────────┐ │  │ ┌──────────────┐ │   │    │
│  │ │ │ Gerado ao salvar│ │  │ │ 13/05/2026  │ │  │ │   14:30      │ │   │    │
│  │ │ └─── #4B5563 ────┘ │  │ └──── #9CA3AF ┘ │  │ └─── #9CA3AF ──┘ │   │    │
│  │ └─────────────────────┘  └─────────────────┘  └──────────────────┘   │    │
│  │                      bg: #F3F4F6 | texto: #9CA3AF                      │    │
│  │ ┌─────────────────────┐  ┌──────────────────────────────────────┐     │    │
│  │ │ Usuário             │  │ Empresa / Contrato                   │     │    │
│  │ │ ┌─────────────────┐ │  │ ┌──────────────────────────────────┐ │     │    │
│  │ │ │Carlos H. Oliveira│ │  │ │Security Dynamics · Operação SD   │ │     │    │
│  │ │ └─── #4B5563 ─────┘ │  │ └── #4B5563 ───────────────────────┘ │     │    │
│  │ └─────────────────────┘  └──────────────────────────────────────┘     │    │
│  │                    Perfil: Supervisor | Depto: Operações                 │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ DADOS DA OBSERVAÇÃO                                                   │    │
│  │                                                                       │    │
│  │  ┌────────────────────────────────────┐ ┌────────────────────────────┐│    │
│  │  │ Empresa Observada *               │ │ Nome do Observado *        ││    │
│  │  │ ┌────────────────────────────────┐ │ │ ┌────────────────────────┐ ││    │
│  │  │ │ Security Dynamics         ▾    │ │ │ │ João Silva Santos      │ ││    │
│  │  │ └────────────────────────────────┘ │ │ └────────────────────────┘ ││    │
│  │  │ ⚠ Outros → campo extra aparece    │ │                            ││    │
│  │  └────────────────────────────────────┘ └────────────────────────────┘│    │
│  │                                                                       │    │
│  │  ┌────────────────────────────────────┐ ┌────────────────────────────┐│    │
│  │  │ Atividade Observada *             │ │ Local Observado *          ││    │
│  │  │ ┌────────────────────────────────┐ │ │ ┌────────────────────────┐ ││    │
│  │  │ │ Operação de empilhadeira       │ │ │ │ Armazém B - Docas      │ ││    │
│  │  │ └────────────────────────────────┘ │ │ └────────────────────────┘ ││    │
│  │  └────────────────────────────────────┘ └────────────────────────────┘│    │
│  │                                                                       │    │
│  │  ┌────────────────────────────────────┐ ┌────────────────────────────┐│    │
│  │  │ Turno *                           │ │ Tipo da Observação *       ││    │
│  │  │ ┌────────────────────────────────┐ │ │                            ││    │
│  │  │ │ Diurno                    ▾    │ │ │ ◉ Positivo / Seguro       ││    │
│  │  │ └────────────────────────────────┘ │ │   ○ Negativo / Inseguro    ││    │
│  │  └────────────────────────────────────┘ └────────────────────────────┘│    │
│  │                                                                       │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │    │
│  │  │ Comportamento Observado *                 0/2000 caracteres      │ │    │
│  │  │ ┌────────────────────────────────────────────────────────────────┐│ │    │
│  │  │ │                                                                ││ │    │
│  │  │ │ Uso correto de todos os EPIs obrigatórios: capacete, luva,     ││ │    │
│  │  │ │ bota de segurança e colete refletivo. Verificou a área antes   ││ │    │
│  │  │ │ de iniciar a operação com empilhadeira. Sinalizou corretamente  ││ │    │
│  │  │ │ o perímetro de segurança.                                       ││ │    │
│  │  │ │                                                         [142]  ││ │    │
│  │  │ └────────────────────────────────────────────────────────────────┘│ │    │
│  │  └──────────────────────────────────────────────────────────────────┘ │    │
│  │                                                                       │    │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │    │
│  │  │ Observação Complementar (opcional)           0/500 caracteres    │ │    │
│  │  │ ┌────────────────────────────────────────────────────────────────┐│ │    │
│  │  │ │                                                                ││ │    │
│  │  │ │ Operador demonstrou atenção redobrada aos procedimentos de     ││ │    │
│  │  │ │ segurança mesmo com a área congestionada.                      ││ │    │
│  │  │ └────────────────────────────────────────────────────────────────┘│ │    │
│  │  └──────────────────────────────────────────────────────────────────┘ │    │
│  │                                                                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                                                                       │    │
│  │   [ 💾 SALVAR REGISTRO ]   [ ↩ CANCELAR ]                            │    │
│  │    bg:#CC0000 text:white   text:#4B5563 border:#E5E7EB               │    │
│  │                                                                       │    │
│  │   * Campos obrigatórios                                              │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Regra "Outros" — Empresa Observada

```
Ao selecionar "Outros" no dropdown de Empresa Observada:

  ┌────────────────────────────────────┐
  │ Empresa Observada *               │
  │ ┌────────────────────────────────┐ │
  │ │ Outros                    ▾    │ │  ← selecionado
  │ └────────────────────────────────┘ │
  └────────────────────────────────────┘
              ↓ aparece com animação slide-down (150ms ease)
  ┌────────────────────────────────────┐
  │ Nome da Empresa Observada *       │
  │ ┌────────────────────────────────┐ │
  │ │ Frigorífico Boi Branco Ltda.  │ │  ← campo texto livre
  │ └────────────────────────────────┘ │
  └────────────────────────────────────┘
```

### 1.3 Estado com Erro de Validação

```
  ┌────────────────────────────────────┐ ┌────────────────────────────┐
  │ Empresa Observada *               │ │ Nome do Observado *        │
  │ ┌────────────────────────────────┐ │ │ ┌────────────────────────┐ │
  │ │ Selecione...              ▾    │ │ │ │                        │ │
  │ └──── border: #EF4444 ──────────┘ │ │ │      (vazio)           │ │
  │ ⚠ Selecione a empresa observada   │ │ └── border: #EF4444 ─────┘ │
  └────────────────────────────────────┘ │ ⚠ Nome do observado é      │
                                         │    obrigatório             │
  ┌────────────────────────────────────┐ └────────────────────────────┘
  │ Comportamento Observado *          │
  │ ┌────────────────────────────────┐ │
  │ │ abc                            │ │
  │ └──── border: #EF4444 ──────────┘ │
  │ ⚠ Mínimo de 10 caracteres          │
  └────────────────────────────────────┘

  Todos os campos inválidos com:
  - borda: 2px solid #EF4444
  - ícone ⚠ AlertTriangle (12px) antes da mensagem
  - mensagem: text-sm (12px) #EF4444, Inter Regular
  - fundo do input: #FEF2F2 (rosa claro)

  Botão SALVAR desabilitado enquanto houver erro:
  [ 💾 SALVAR REGISTRO ]  ← opacity: 50%, cursor: not-allowed, bg: #9CA3AF
```

### 1.4 Estado Salvando (Loading)

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                                                                       │
  │   [ ◐ SALVANDO... ]   [ ↩ CANCELAR ]                                │
  │    bg:#990000           opacity:50%                                   │
  │                                                                       │
  │  ┌────────────────────────────────────────────────────────────────┐  │
  │  │            Todos os campos desabilitados (disabled)             │  │
  │  │            com opacidade reduzida e cursor not-allowed           │  │
  │  └────────────────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────────────────┘
```

### 1.5 Feedback Pós-Salvar (Toast + Modal de Sucesso)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │                                                                           │ │
│ │                           ✅ SUCESSO!                                     │ │
│ │                                                                           │ │
│ │                 Registro OFS/OFS gerado com sucesso                       │ │
│ │                                                                           │ │
│ │                        ┌──────────────┐                                   │ │
│ │                        │              │                                   │ │
│ │                        │  OFS #1523   │  ← Inter Bold 48px #1A1A1A       │ │
│ │                        │              │                                   │ │
│ │                        └──────────────┘                                   │ │
│ │                                                                           │ │
│ │             📅 13/05/2026  ⏰ 14:30  🏷 Positivo / Seguro                 │ │
│ │             👤 João Silva Santos  🏢 Security Dynamics                   │ │
│ │                                                                           │ │
│ │      ┌──────────────────────┐    ┌──────────────────────┐                │ │
│ │      │  👁 VER REGISTRO    │    │  ➕ NOVA OFS/OFS     │                │ │
│ │      │  bg:#CC0000 white   │    │  border:#CC0000      │                │ │
│ │      └──────────────────────┘    └──────────────────────┘                │ │
│ │                                                                           │ │
│ │                      [ ↩ VOLTAR AO INÍCIO ]                              │ │
│ │                                                                           │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ═══════════════════════════════════════════════════════════════════════════ │
│  TOAST (canto superior direito, auto-dismiss 5s):                            │
│  ┌──────────────────────────────────────────┐                                │
│  │ ✅ Registro OFS #1523 salvo com sucesso  │  bg: #DCFCE7 border: #22C55E  │
│  └──────────────────────────────────────────┘                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. WIREFRAME — TELA CONSULTA

### 2.1 Estado Normal (Desktop 1280px)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ┌────────┐  ┌───────────────────────────────────────────────────────────────┐│
│ │ ☰ MENU │  │ CONSULTA DE REGISTROS OFS/OFS                   Resultado: 47 ││
│ └────────┘  └───────────────────────────────────────────────────────────────┘│
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ FILTROS                                                               │    │
│  │                                                                       │    │
│  │ ┌──────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐  │    │
│  │ │ Código   │ │ Data Início  │ │ Data Fim     │ │ Empresa      ▾  │  │    │
│  │ │ ┌──────┐ │ │ ┌──────────┐ │ │ ┌──────────┐ │ │ ┌──────────────┐ │  │    │
│  │ │ │ 1523  │ │ │ │01/05/2026│ │ │ │13/05/2026│ │ │ │Todas         │ │  │    │
│  │ │ └──────┘ │ │ └──────────┘ │ │ └──────────┘ │ │ └──────────────┘ │  │    │
│  │ └──────────┘ └──────────────┘ └──────────────┘ └──────────────────┘  │    │
│  │                                                                       │    │
│  │ ┌──────────────┐ ┌──────────────────┐ ┌──────────────────┐           │    │
│  │ │ Contrato ▾   │ │ Turno        ▾   │ │ Tipo           ▾ │           │    │
│  │ │ ┌──────────┐ │ │ ┌──────────────┐ │ │ ┌──────────────┐ │           │    │
│  │ │ │Todos      │ │ │ │Todos         │ │ │ │Todos         │ │           │    │
│  │ │ └──────────┘ │ │ └──────────────┘ │ │ └──────────────┘ │           │    │
│  │ └──────────────┘ └──────────────────┘ └──────────────────┘           │    │
│  │                                                                       │    │
│  │ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐       │    │
│  │ │ Status       ▾   │ │ Usuário          │ │ Período Ráp. ▾   │       │    │
│  │ │ ┌──────────────┐ │ │ ┌──────────────┐ │ │ ┌──────────────┐ │       │    │
│  │ │ │Todos         │ │ │ │Carlos Hen..  │ │ │ │Hoje          │ │       │    │
│  │ │ └──────────────┘ │ │ └──────────────┘ │ │ └──────────────┘ │       │    │
│  │ └──────────────────┘ └──────────────────┘ └──────────────────┘       │    │
│  │                                                                       │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────┐       │    │
│  │  │ 🔍 BUSCAR    │  │ 🗑 LIMPAR    │  │ 📄 GERAR PDF DOS      │       │    │
│  │  │ bg: #CC0000  │  │ FILTROS      │  │    RESULTADOS         │       │    │
│  │  └──────────────┘  └──────────────┘  └───────────────────────┘       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ RESULTADOS                                       25 itens/página ▾    │    │
│  │                                                                       │    │
│  │ ┌──────────────────────────────────────────────────────────────────┐ │    │
│  │ │Código▾│ Data/Hora   │Observado       │Empresa   │Tipo       │Sta│Aç│ │    │
│  │ ├──────────────────────────────────────────────────────────────────┤ │    │
│  │ │ #1523 │13/05 14:30  │João Silva S.   │Sec.Dyn.  │✅ Positivo│Ger│👁│ │    │
│  │ │ #1522 │13/05 09:15  │Maria Souza     │G4S       │❌ Negativo│Ger│👁│ │    │
│  │ │ #1521 │12/05 16:40  │Pedro Lima      │ERA       │✅ Positivo│Edt│👁│ │    │
│  │ │ #1520 │12/05 11:20  │Ana Costa       │Polo Norte│⚠ Neutro  │Ger│👁│ │    │
│  │ │ #1519 │12/05 08:05  │Lucas Santos    │Sec.Dyn.  │❌ Negativo│Cnc│👁│ │    │
│  │ │ #1518 │11/05 15:55  │Fernanda Alves  │G4S       │✅ Positivo│Ger│👁│ │    │
│  │ │ #1517 │11/05 14:30  │Rafael Moreira  │ERA       │✅ Positivo│Ger│👁│ │    │
│  │ │ #1516 │11/05 10:10  │Camila Rocha    │Sec.Dyn.  │❌ Negativo│Edt│👁│ │    │
│  │ │ #1515 │11/05 07:45  │Bruno Neves     │Polo Norte│✅ Positivo│Ger│👁│ │    │
│  │ │ #1514 │10/05 16:20  │Patrícia Dias   │ERA       │⚠ Neutro  │Ger│👁│ │    │
│  │ └──────────────────────────────────────────────────────────────────┘ │    │
│  │                                                                       │    │
│  │  Hover na linha: bg: #FEF2F2                                          │    │
│  │                                                                       │    │
│  │  ◀ ◀  ← Página 3 de 5 →  ▶ ▶                                       │    │
│  │     1  2  [3]  4  5                                                  │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  COLUNA AÇÕES (ícones 18px, gap 8px, tooltip no hover):                      │
│  ┌──────────────────────────────────────────────────────────────────┐        │
│  │ 👁 = Ver registro     📄 = Gerar PDF     ✏ = Editar   ⛔ = Cancelar│        │
│  │  #4B5563              #4B5563             #3B82F6       #EF4444    │        │
│  │  hover:#CC0000        hover:#CC0000       hover:#2563EB hover:#DC2626│      │
│  └──────────────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Estado Loading (Skeleton)

```
  ┌──────────────────────────────────────────────────────────────────┐
  │ RESULTADOS                                                       │
  │                                                                   │
  │ ┌──────────────────────────────────────────────────────────────┐ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ ├──────────────────────────────────────────────────────────────┤ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ │ ▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓ │ ▓▓▓▓▓▓▓  │ │
  │ └──────────────────────────────────────────────────────────────┘ │
  │                                                                   │
  │  As barras ▓▓▓ pulsam com animação animate-pulse                  │
  │  bg: #E5E7EB, rounded, altura variável 12-16px por linha          │
  └──────────────────────────────────────────────────────────────────┘
```

### 2.3 Estado Vazio

```
  ┌──────────────────────────────────────────────────────────────────┐
  │ RESULTADOS                                                       │
  │                                                                   │
  │                                                                   │
  │                         ┌────┐                                    │
  │                         │ 📦 │  ← PackageOpen icon 48px #9CA3AF  │
  │                         └────┘                                    │
  │                                                                   │
  │                   Nenhum registro encontrado                      │
  │              text-lg (18px) Inter SemiBold #4B5563                │
  │                                                                   │
  │         Que tal registrar sua primeira OFS/OFS agora?             │
  │              text-sm (14px) Inter Regular #9CA3AF                 │
  │                                                                   │
  │                   ┌──────────────────────┐                        │
  │                   │  ➕ NOVA OFS/OFS     │                        │
  │                   └──────────────────────┘                        │
  │                         (se aplicável)                            │
  │                                                                   │
  └──────────────────────────────────────────────────────────────────┘
```

### 2.4 Estado Vazio com Filtros Ativos

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                                                                   │
  │                         ┌────┐                                    │
  │                         │ 🔍 │  ← Search icon 48px #9CA3AF       │
  │                         └────┘                                    │
  │                                                                   │
  │            Nenhum resultado para os filtros aplicados             │
  │                                                                   │
  │          Tente alterar os critérios de busca ou limpar            │
  │                     todos os filtros.                             │
  │                                                                   │
  │                   ┌──────────────────────┐                        │
  │                   │  🗑 LIMPAR FILTROS   │                        │
  │                   └──────────────────────┘                        │
  │                                                                   │
  └──────────────────────────────────────────────────────────────────┘
```

### 2.5 Estado de Erro

```
  ┌──────────────────────────────────────────────────────────────────┐
  │                                                                   │
  │                        ┌────┐                                     │
  │                        │ ❌ │  ← XCircle icon 48px #EF4444        │
  │                        └────┘                                     │
  │                                                                   │
  │              Não foi possível carregar os dados                   │
  │                                                                   │
  │          Verifique sua conexão com a rede local ou tente          │
  │                     novamente em instantes.                       │
  │                                                                   │
  │                   ┌──────────────────────┐                        │
  │                   │  🔄 TENTAR NOVAMENTE │                        │
  │                   └──────────────────────┘                        │
  │                                                                   │
  └──────────────────────────────────────────────────────────────────┘
```

### 2.6 Dropdown de Ações por Linha (Mobile)

```
No mobile, as ações ficam em um dropdown (...) ao final da linha:

  ┌─────────────────────────────────────────────┐
  │ #1523 · 13/05 · João Silva                  │
  │ Sec.Dyn · ✅ Positivo · Gerado    [··· ▾]    │
  ├─────────────────────────────────────────────┤
  │ #1522 · 13/05 · Maria Souza                 │
  │ G4S · ❌ Negativo · Gerado       [··· ▾]    │
  └─────────────────────────────────────────────┘

  Ao clicar [···]:
  ┌─────────────┐
  │ 👁 Ver       │
  │ 📄 PDF       │
  │ ✏ Editar     │  ← condicional
  │ ⛔ Cancelar   │  ← condicional
  └─────────────┘
```

---

## 3. WIREFRAME — TELA VISUALIZAÇÃO

### 3.1 Estado Normal (Desktop 1280px)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ┌────────┐  ┌───────────────────────────────────────────────────────────────┐│
│ │ ☰ MENU │  │ ← VOLTAR      VISUALIZAR REGISTRO OFS/OFS                    ││
│ └────────┘  └───────────────────────────────────────────────────────────────┘│
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ CABEÇALHO DO DOCUMENTO                                                │    │
│  │                                                                       │    │
│  │  ┌─────────────────────────────────────┐  ┌─────────────────────────┐ │    │
│  │  │                                     │  │                         │ │    │
│  │  │  [LOGO SD]   Security Dynamics      │  │  OFS/OFS Nº  1523/2026  │ │    │
│  │  │              OFS - Ordem de         │  │                         │ │    │
│  │  │              Fiscalização de Campo  │  │  ┌────────────────────┐ │ │    │
│  │  │                                     │  │  │   🟢 GERADO       │ │ │    │
│  │  │                                     │  │  └────────────────────┘ │ │    │
│  │  └─────────────────────────────────────┘  └─────────────────────────┘ │    │
│  │                                                                       │    │
│  │  ┌──────────────────────────────────────────────────────────────┐    │    │
│  │  │ DADOS GERAIS                    │ DADOS DA OBSERVAÇÃO         │    │    │
│  │  ├─────────────────────────────────┼─────────────────────────────┤    │    │
│  │  │                                 │                             │    │    │
│  │  │ 📅 Data:     13/05/2026         │ 🏢 Empresa: Sec. Dynamics   │    │    │
│  │  │ ⏰ Hora:     14:30              │ 👤 Observado: João Silva S. │    │    │
│  │  │ 📆 Semana:   20/2026            │ 🏗 Atividade: Oper. Empilh. │    │    │
│  │  │ 👤 Gerado por: Carlos Oliveira  │ 📍 Local: Armazém B - Docas │    │    │
│  │  │ 👔 Perfil:   Supervisor         │ 🕐 Turno: Diurno            │    │    │
│  │  │ 🏢 Empresa:  Security Dynamics  │ 📋 Contrato: Operação SD    │    │    │
│  │  │                                 │                             │    │    │
│  │  └─────────────────────────────────┴─────────────────────────────┘    │    │
│  │   border: 1px solid #E5E7EB  |  labels: text-xs #9CA3AF  |           │    │
│  │   values: text-sm #1A1A1A Inter SemiBold                             │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                                                                       │    │
│  │  ┌─────────────────────────────────────────────────────────────┐     │    │
│  │  │                    ✅ POSITIVO / SEGURO                      │     │    │
│  │  │                    bg: #DCFCE7 text: #16A34A                 │     │    │
│  │  │                    (se Negativo: bg: #FEE2E2 text: #DC2626)  │     │    │
│  │  └─────────────────────────────────────────────────────────────┘     │    │
│  │                                                                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ COMPORTAMENTO OBSERVADO                                               │    │
│  │                                                                       │    │
│  │ Uso correto de todos os EPIs obrigatórios: capacete, luva, bota de    │    │
│  │ segurança e colete refletivo. Verificou a área antes de iniciar a     │    │
│  │ operação com empilhadeira. Sinalizou corretamente o perímetro de      │    │
│  │ segurança. Demonstrou conhecimento dos procedimentos operacionais.    │    │
│  │                                                                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ OBSERVAÇÃO COMPLEMENTAR                                               │    │
│  │                                                                       │    │
│  │ Operador demonstrou atenção redobrada aos procedimentos de segurança  │    │
│  │ mesmo com a área congestionada. Atitude proativa merece destaque.     │    │
│  │                                                                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │ HISTÓRICO DE ALTERAÇÕES                       📋 3 alterações         │    │
│  │                                                                       │    │
│  │ ┌──────────────┬──────────────┬────────────┬──────────┬──────────┐   │    │
│  │ │ Data/Hora    │ Usuário      │ Campo      │ De       │ Para     │   │    │
│  │ ├──────────────┼──────────────┼────────────┼──────────┼──────────┤   │    │
│  │ │13/05 16:45   │ Carlos Olive │ Comportam. │ Uso cor..│ Uso cor..│   │    │
│  │ │              │ (Supervisor) │            │          │ eto dos..│   │    │
│  │ ├──────────────┼──────────────┼────────────┼──────────┼──────────┤   │    │
│  │ │13/05 17:10   │ Carlos Olive │ Observação │ Operador.│ Operador.│   │    │
│  │ │              │ (Supervisor) │ Complement.│ demons.. │ demons.. │   │    │
│  │ │              │              │            │          │ (ampli..)│   │    │
│  │ ├──────────────┼──────────────┼────────────┼──────────┼──────────┤   │    │
│  │ │14/05 08:20   │ Admin SD     │ Status     │ Gerado   │ Editado  │   │    │
│  │ │              │ (Admin)      │            │          │          │   │    │
│  │ └──────────────┴──────────────┴────────────┴──────────┴──────────┘   │    │
│  │                                                                       │    │
│  │  (Se nunca editado → "Nenhuma alteração registrada neste OFS")       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                                                                       │    │
│  │  [ 📄 GERAR PDF ]  [ ✏ EDITAR ]  [ ⛔ CANCELAR ]  [ ↩ VOLTAR ]       │    │
│  │   bg:#CC0000        border:#E5E7  border:#FEE2E2   text:#4B5563       │    │
│  │   text:white        text:#1A1A1A  text:#DC2626                         │    │
│  │   hover:#990000     hover:#F3F4F6 hover:#FEE2E2                        │    │
│  │                                                                       │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Badges de Status (Variações)

```
  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
  │   🟢 GERADO      │   │   🟡 EDITADO     │   │   🔴 CANCELADO   │
  │ bg:#DCFCE7       │   │ bg:#FEF9C3       │   │ bg:#FEE2E2       │
  │ text:#16A34A     │   │ text:#CA8A04     │   │ text:#DC2626     │
  │ border:#BBF7D0   │   │ border:#FDE68A   │   │ border:#FECACA   │
  └──────────────────┘   └──────────────────┘   └──────────────────┘
      Inter SemiBold 12px uppercase tracking-wider rounded-full px-3 py-1
```

### 3.3 Badges de Tipo (Variações)

```
  ┌──────────────────────────────┐ ┌──────────────────────────────┐
  │  ✅ POSITIVO / SEGURO        │ │  ❌ NEGATIVO / INSEGURO      │
  │  bg: #DCFCE7 text: #16A34A   │ │  bg: #FEE2E2 text: #DC2626   │
  │  (faixa full-width no card)  │ │  (faixa full-width no card)  │
  └──────────────────────────────┘ └──────────────────────────────┘
      24px de altura, Inter Bold 14px uppercase tracking-wide

  ┌──────────────────────────────┐
  │  ⚠ NEUTRO                    │
  │  bg: #DBEAFE text: #3B82F6   │
  └──────────────────────────────┘
```

### 3.4 Modal de Cancelamento

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                                                                       │
  │                        ┌─────────────────────┐                       │
  │                        │                     │                       │
  │                        │  ⛔ CANCELAR OFS     │                       │
  │                        │                     │                       │
  │                        │ Tem certeza que     │                       │
  │                        │ deseja cancelar o   │                       │
  │                        │ registro OFS #1523? │                       │
  │                        │                     │                       │
  │                        │ Esta ação não pode  │                       │
  │                        │ ser desfeita.       │                       │
  │                        │                     │                       │
  │                        │ Motivo do           │                       │
  │                        │ cancelamento *      │                       │
  │                        │ ┌─────────────────┐ │                       │
  │                        │ │                 │ │                       │
  │                        │ └─────────────────┘ │                       │
  │                        │                     │                       │
  │                        │  [ CONFIRMAR ]      │                       │
  │                        │  [ VOLTAR ]         │                       │
  │                        │                     │                       │
  │                        └─────────────────────┘                       │
  │                          card centralizado                            │
  │                          backdrop: rgba(0,0,0,0.4)                   │
  └──────────────────────────────────────────────────────────────────────┘
```

### 3.5 OFS Cancelada (Visualização)

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                                                                       │
  │  ┌────────────────────────────────────────────────────────────────┐  │
  │  │ ⚠ ESTE REGISTRO FOI CANCELADO                                   │  │
  │  │ bg: #FEF2F2 border: #FECACA text: #DC2626                       │  │
  │  │                                                                  │  │
  │  │ Cancelado por: Admin SD (Administrador)                          │  │
  │  │ Data: 14/05/2026 às 09:15                                        │  │
  │  │ Motivo: Registro duplicado. Ver OFS #1524 para o mesmo evento.  │  │
  │  └────────────────────────────────────────────────────────────────┘  │
  │                                                                       │
  │  Botões exibidos: [ 📄 GERAR PDF ] [ ↩ VOLTAR ]                     │
  │  (Edit e Cancel ocultos para registros já cancelados)                 │
  └──────────────────────────────────────────────────────────────────────┘
```

---

## 4. COMPONENTES REACT

### 4.1 Estrutura de Arquivos

```
src/
├── components/
│   ├── ui/                          # Base (shared)
│   │   ├── Button.tsx               # variant: primary|secondary|danger|ghost
│   │   ├── Input.tsx                # label, error, disabled, icon
│   │   ├── Select.tsx               # options[{value,label}], searchable
│   │   ├── Textarea.tsx             # label, rows, charCount, error
│   │   ├── DatePicker.tsx           # input type="date" estilizado
│   │   ├── RadioGroup.tsx           # options[{value,label}], direction=row|col
│   │   ├── Badge.tsx                # variant: success|warning|danger|info
│   │   ├── Spinner.tsx              # size: sm|md|lg
│   │   ├── Skeleton.tsx             # width, height, className
│   │   ├── Toast.tsx                # wrapper sobre sonner, config global
│   │   ├── Modal.tsx                # open, onClose, title, size, children
│   │   ├── EmptyState.tsx           # icon, title, description, action
│   │   └── ErrorState.tsx           # title, message, onRetry
│   │
│   ├── layout/
│   │   ├── AppShell.tsx             # Header + Sidebar + <Outlet/>
│   │   ├── Header.tsx               # Logo, título, userMenu, hamburger
│   │   ├── Sidebar.tsx              # NavLinks por perfil, overlay mobile
│   │   ├── PageHeader.tsx           # title, subtitle, onBack, actions
│   │   └── Breadcrumb.tsx           # path segments automáticos
│   │
│   ├── OFS/                         # Específicos do módulo OFS
│   │   ├── NovaOFC/
│   │   │   ├── NovaOFCForm.tsx          # Container principal do formulário
│   │   │   ├── AutoFieldsCard.tsx       # Card cinza: código, data, hora, user, empresa
│   │   │   ├── EmpresaObservadaSelect.tsx# Dropdown 15 empresas + campo "Outros"
│   │   │   ├── NomeEmpresaExtraInput.tsx # Campo condicional (Outros)
│   │   │   ├── FormRow.tsx              # Layout 2 colunas para campos em par
│   │   │   ├── TipoObservacaoRadio.tsx  # Radio: Positivo/Negativo/Neutro
│   │   │   ├── CharCounter.tsx          # Contador X/2000 no textarea
│   │   │   ├── ValidationMessage.tsx    # Mensagem de erro inline
│   │   │   ├── FormActions.tsx          # Botões Salvar + Cancelar
│   │   │   └── SaveSuccessModal.tsx     # Modal pós-salvar (ver/novo/voltar)
│   │   │
│   │   ├── Consulta/
│   │   │   ├── ConsultaPage.tsx         # Container: filtros + tabela
│   │   │   ├── FilterBar.tsx            # Barra de filtros colapsável
│   │   │   ├── FilterField.tsx          # Campo individual de filtro
│   │   │   ├── QuickPeriodSelect.tsx    # Dropdown: Hoje/Semana/Mês/Trimestre
│   │   │   ├── ResultTable.tsx          # Tabela de resultados
│   │   │   ├── TableHeader.tsx          # Cabeçalho com sort
│   │   │   ├── TableRow.tsx             # Linha com ações
│   │   │   ├── RowActions.tsx           # 👁 📄 ✏ ⛔ (dropdown mobile)
│   │   │   ├── TableSkeleton.tsx        # Skeleton para estado loading
│   │   │   ├── TableEmpty.tsx           # Estado vazio
│   │   │   ├── TableError.tsx           # Estado de erro
│   │   │   └── Pagination.tsx           # Navegação de páginas
│   │   │
│   │   ├── Visualizacao/
│   │   │   ├── VisualizacaoPage.tsx     # Container: documento OFS
│   │   │   ├── DocumentHeader.tsx       # Logo + nº OFS + badge status
│   │   │   ├── DadosGeraisGrid.tsx      # Grid 2 colunas dados gerais
│   │   │   ├── TipoBadge.tsx            # Faixa colorida Positivo/Negativo/Neutro
│   │   │   ├── SectionCard.tsx          # Card de seção (Comportamento, Observação)
│   │   │   ├── HistoricoEdicoes.tsx     # Tabela de alterações
│   │   │   ├── HistoricoTable.tsx       # Linhas: campo/antes/depois/quem/quando
│   │   │   ├── StatusBadge.tsx          # Gerado/Editado/Cancelado
│   │   │   ├── CancelBanner.tsx         # Banner de OFS cancelada
│   │   │   ├── CancelModal.tsx          # Modal de confirmação de cancelamento
│   │   │   ├── DocumentActions.tsx      # Botões: PDF, Editar, Cancelar, Voltar
│   │   │   └── GerarPDFButton.tsx       # Botão com estado "Gerando..."
│   │   │
│   │   └── shared/
│   │       ├── StatusBadge.tsx          # Reutilizado em tabela e visualização
│   │       ├── TipoBadge.tsx            # Reutilizado em tabela e visualização
│   │       └── useOFCQuery.ts           # Hook: fetch por ID, cache
│   │
│   └── hooks/
│       ├── useAuth.ts                   # Contexto: user, empresa, contrato, role
│       ├── useFormValidation.ts         # Validação inline, errors map
│       ├── useDebounce.ts               # Debounce para filtros
│       └── useMediaQuery.ts             # Breakpoints responsivos
```

### 4.2 Descrição de Cada Componente

#### 🔷 NovaOFCForm.tsx
**Container principal.** Gerencia o estado do formulário via `useReducer`. Orquestra validação, submissão e feedback. Renderiza `AutoFieldsCard` + grid de campos editáveis em 2 colunas (desktop) ou 1 coluna (mobile).

#### 🔷 AutoFieldsCard.tsx
**Card cinza com campos bloqueados.** Exibe: Código (placeholder "Gerado ao salvar"), Data (atual), Hora (atual), Usuário logado (nome + perfil), Empresa do contrato, Nome do contrato. Fundo `#F3F4F6`, inputs com `disabled`, texto `#9CA3AF`. Recebe `user: User`, `contract: Contract`.

#### 🔷 EmpresaObservadaSelect.tsx
**Dropdown de empresa observada.** Busca lista de empresas via API (ou cache local, ~15 registros). Sempre inclui opção "Outros" como último item. Ao selecionar "Outros", emite evento `onSelectOutros()` que exibe `NomeEmpresaExtraInput`. Usa `Select` base com busca textual (filtra enquanto digita).

#### 🔷 NomeEmpresaExtraInput.tsx
**Campo condicional.** Visível apenas quando `empresaObservada === 'outros'`. Animação de entrada: `slide-down 150ms ease`. Campo obrigatório com label "Nome da Empresa Observada *". Validação: mínimo 3 caracteres. Ao desselecionar "Outros", limpa valor e oculta.

#### 🔷 FormRow.tsx
**Layout wrapper para pares de campos.** Desktop: `grid grid-cols-2 gap-md`. Mobile: `grid grid-cols-1 gap-sm`. Recebe `children` como array de 2 elementos. Usado para: (Empresa, Nome) — (Atividade, Local) — (Turno, Tipo).

#### 🔷 TipoObservacaoRadio.tsx
**Radio group para tipo da OFS.** Opções: `○ Positivo / Seguro`, `○ Negativo / Inseguro`, `○ Neutro`. Cor do radio selecionado: `#CC0000`. Opção "Neutro" só aparece se feature flag `allowNeutral=true` (MVP padrão: desabilitado, só Positivo/Negativo). Validação: obrigatório.

#### 🔷 CharCounter.tsx
**Contador de caracteres no rodapé do textarea.** Exibe `{current}/{max}`. Cor normal: `#9CA3AF`. Próximo do limite (90%+): `#EAB308`. Estouro: `#EF4444`. Usado em Comportamento (max 2000) e Observação Complementar (max 500).

#### 🔷 ValidationMessage.tsx
**Mensagem de erro inline.** Renderiza condicionalmente abaixo de um campo. Exibe ícone `⚠ AlertTriangle` 12px + texto `text-sm #EF4444`. Só aparece quando o campo perdeu o foco (`touched`) e tem erro. Exemplo: `"Nome do observado é obrigatório"`, `"Mínimo de 10 caracteres"`.

#### 🔷 FormActions.tsx
**Barra de botões fixa no rodapé ou ao final do form.** Botão primário `Salvar` (`bg:#CC0000`, desabilitado se inválido ou salvando, mostra `◐ SALVANDO...` com Spinner durante submit). Botão secundário `Cancelar` (`border:#E5E7EB`, redireciona para `/` ou rota anterior). Desktop: lado a lado. Mobile: empilhados full-width.

#### 🔷 SaveSuccessModal.tsx
**Modal de sucesso pós-salvar.** Centralizado com backdrop. Exibe: ✅ ícone, "Registro OFS/OFS gerado com sucesso", número grande `OFS #1523`, dados resumidos (data, tipo, observado, empresa). 3 botões: `👁 Ver registro` (navega para `/OFS/:id`), `➕ Nova OFS/OFS` (reseta form), `↩ Voltar ao início` (navega para `/`). TOAST simultâneo no canto superior direito. Auto-dismiss do toast em 5s.

#### 🔷 ConsultaPage.tsx
**Container da tela de consulta.** Gerencia estado de filtros (`useState`), resultados (`useQuery`), paginação e ordenação. Renderiza `FilterBar` + `ResultTable` (ou `TableSkeleton` / `TableEmpty` / `TableError`). Aplica debounce de 400ms ao digitar em campos de texto.

#### 🔷 FilterBar.tsx
**Barra de filtros horizontal.** Desktop: campos lado a lado em grid 4-5 colunas. Mobile: colapsável via toggle `[▼ FILTROS]`. Campos: código (input number), data início (date), data fim (date), empresa (select), contrato (select), turno (select), tipo (select), status (select), usuário (select com busca). Botões: `🔍 Buscar`, `🗑 Limpar filtros`, `📄 Gerar PDF`. Contador de resultados ativo.

#### 🔷 FilterField.tsx
**Campo individual de filtro.** Wrapper sobre `Input`, `Select`, ou `DatePicker`. Suporta prop `onChange` com debounce automático. Label acima do campo em `text-xs #9CA3AF`. Placeholder dentro do campo.

#### 🔷 QuickPeriodSelect.tsx
**Atalhos de período.** Dropdown com opções: "Hoje", "Últimos 7 dias", "Esta semana", "Este mês", "Último mês", "Este trimestre". Ao selecionar, preenche automaticamente `dataInicio` e `dataFim`.

#### 🔷 ResultTable.tsx
**Tabela de resultados principal.** Colunas: Código, Data/Hora, Observado, Empresa, Tipo, Status, Ações. Suporte a sort (clique no cabeçalho). Linhas com hover `bg: #FEF2F2`. Altura fixa `max-h-[60vh]` com scroll vertical. Renderiza `TableSkeleton` durante loading, `TableEmpty` quando sem dados, `TableError` em falha.

#### 🔷 TableHeader.tsx
**Cabeçalho com indicador de ordenação.** Recebe `columns[]`, `sortKey`, `sortDir`. Colunas ordenáveis mostram `▾` ou `▴` ao lado do label. Clique alterna direção ou troca coluna.

#### 🔷 TableRow.tsx
**Linha de dados da tabela.** Renderiza células conforme `columns[]`. Última coluna sempre é ações. Clique na linha (fora das ações) navega para visualização (`/OFS/:id`). Cursor: `pointer`.

#### 🔷 RowActions.tsx
**Ícones de ação por linha.** Desktop: ícones lado a lado com gap 8px e tooltip. Mobile: botão `[···]` que abre dropdown. Ações disponíveis conforme `Regras de Visibilidade` (seção 5). Ícones: `👁 Eye` (ver), `📄 FileText` (PDF), `✏ Pencil` (editar, condicional), `⛔ Ban` (cancelar, condicional). Cores: cinza padrão, hover muda para cor de destaque.

#### 🔷 TableSkeleton.tsx
**10 linhas de placeholder pulsante.** Cada linha com barras `bg:#E5E7EB rounded` de larguras variadas simulando células. Animação `animate-pulse`. Exibido durante `isLoading=true`.

#### 🔷 TableEmpty.tsx
**Estado vazio.** Usa `EmptyState` com ícone `📦 PackageOpen`, título "Nenhum registro encontrado", descrição contextual. Se há filtros ativos, sugere limpar filtros. Se sem filtros, sugere criar primeira OFS.

#### 🔷 TableError.tsx
**Estado de erro.** Usa `ErrorState` com ícone `❌ XCircle`, título "Não foi possível carregar os dados", botão "Tentar novamente" que chama `onRetry()`.

#### 🔷 Pagination.tsx
**Controles de paginação.** Exibe: `◀◀ ◀ ← Página X de Y → ▶ ▶▶` com números de página clicáveis. Página atual destacada `bg:#CC0000 text:white`. Dropdown de itens/página: 10, 25, 50, 100. Total de registros visível. Validações: não navegar além dos limites.

#### 🔷 VisualizacaoPage.tsx
**Container da visualização.** Busca OFS por ID via `useOFCQuery`. Renderiza layout de documento em card branco com sombra simulando folha A4. Seções: `DocumentHeader`, `DadosGeraisGrid`, `TipoBadge`, `SectionCard` (Comportamento), `SectionCard` (Observação), `HistoricoEdicoes`. Botões: `DocumentActions`. Banner `CancelBanner` se OFS cancelada.

#### 🔷 DocumentHeader.tsx
**Cabeçalho estilo documento oficial.** Lado esquerdo: logo SD, nome da empresa, "OFS - Ordem de Fiscalização de Campo". Lado direito: nº do OFS (ex: 1523/2026), `StatusBadge` abaixo. Fundo branco, borda inferior `#E5E7EB`.

#### 🔷 DadosGeraisGrid.tsx
**Grid 2 colunas com dados do registro.** Cada célula: label em `text-xs #9CA3AF` + valor em `text-sm #1A1A1A Inter SemiBold`. Coluna esquerda: Data, Hora, Semana, Gerado por, Perfil, Empresa. Coluna direita: Empresa Observada, Observado, Atividade, Local, Turno, Contrato.

#### 🔷 TipoBadge.tsx
**Faixa colorida indicando o tipo.** Ocupa largura total do card. Positivo: `bg:#DCFCE7 text:#16A34A`. Negativo: `bg:#FEE2E2 text:#DC2626`. Neutro: `bg:#DBEAFE text:#3B82F6`. Texto centralizado, uppercase, bold.

#### 🔷 SectionCard.tsx
**Card de seção de conteúdo.** Título da seção (ex: "COMPORTAMENTO OBSERVADO") em `text-sm Inter SemiBold #4B5563 uppercase`. Conteúdo textual abaixo com `text-sm Inter Regular #1A1A1A`. Usado para Comportamento e Observação Complementar.

#### 🔷 HistoricoEdicoes.tsx
**Seção de histórico de alterações.** Título: "HISTÓRICO DE ALTERAÇÕES" + contador. Tabela com colunas: Data/Hora, Usuário (nome + perfil), Campo alterado, De (valor antigo truncado), Para (valor novo truncado). Se sem alterações, mensagem: "Nenhuma alteração registrada neste OFS" em `text-sm #9CA3AF`.

#### 🔷 HistoricoTable.tsx
**Tabela interna do histórico.** Linhas zebradas (`bg:#F9FAFB` alternado). Valores longos truncados com `...` e tooltip expandido no hover. Usuário exibido com nome + perfil entre parênteses.

#### 🔷 StatusBadge.tsx
**Badge do status do registro.** Variantes:
- `gerado`: `🟢 GERADO` — `bg:#DCFCE7 text:#16A34A`
- `editado`: `🟡 EDITADO` — `bg:#FEF9C3 text:#CA8A04`
- `cancelado`: `🔴 CANCELADO` — `bg:#FEE2E2 text:#DC2626`

Formato pill (`rounded-full`), uppercase, `text-xs` tracking-wide. Usado em tabelas, visualização e cabeçalho.

#### 🔷 CancelBanner.tsx
**Banner de aviso em OFCs canceladas.** Faixa amarela/vermelha clara no topo do documento: "⚠ ESTE REGISTRO FOI CANCELADO". Abaixo: nome de quem cancelou, data/hora, motivo. Ocupa 100% da largura. Botões de edição e cancelamento ocultos.

#### 🔷 CancelModal.tsx
**Modal de confirmação de cancelamento.** Exibe: "Tem certeza que deseja cancelar o registro OFS #XXXX?", "Esta ação não pode ser desfeita.", textarea obrigatório "Motivo do cancelamento *", botões `Confirmar` (danger) e `Voltar` (ghost). Validação: motivo obrigatório, mínimo 10 caracteres.

#### 🔷 DocumentActions.tsx
**Barra de botões de ação no documento.** Condicionais conforme regras de visibilidade (seção 5). Botões: `📄 GERAR PDF` (primary), `✏ EDITAR` (secondary, condicional), `⛔ CANCELAR` (danger, condicional), `↩ VOLTAR` (ghost). Comportamento responsivo: desktop lado a lado, mobile empilhados.

#### 🔷 GerarPDFButton.tsx
**Botão com estado de geração.** Estado normal: "📄 GERAR PDF". Estado loading: "◐ GERANDO..." com Spinner. Ao concluir: dispara download do PDF e mostra toast "PDF gerado com sucesso!". Em erro: toast "Erro ao gerar PDF. Tente novamente.".

#### 🔷 useOFCQuery.ts
**Hook de dados.** Busca OFS por ID via API local. Retorna `{ data, isLoading, error, refetch }`. Cache em memória (não há IndexedDB no MVP). Trata erros de rede e 404.

#### 🔷 useFormValidation.ts
**Hook de validação.** Recebe esquema de validação (campos, regras). Retorna `{ errors, validate, validateField, isValid, isDirty }`. Regras: required, minLength, maxLength, pattern. Validação inline: `validateField(name)` no onBlur. Validação completa: `validate()` no submit.

---

## 5. REGRAS DE VISIBILIDADE

### 5.1 Matriz de Ações por Perfil × Status

```
┌──────────────────┬────────────┬────────────┬────────────┬────────────┐
│                  │ Observador │ Supervisor │   Gestor   │   Admin    │
│                  │ (employee) │(supervisor)│ (manager)  │  (admin)   │
├──────────────────┼────────────┼────────────┼────────────┼────────────┤
│ VER (👁)         │   próprio  │  contrato  │   todos    │   todos    │
│                  │            │            │            │            │
│ PDF (📄)         │   próprio  │  contrato  │   todos    │   todos    │
│                  │            │            │            │            │
│ EDITAR (✏)      │   próprio  │  contrato  │   todos    │   todos    │
│                  │  até 24h   │  até 48h   │ s/ limite  │ s/ limite  │
│                  │            │            │            │            │
│ CANCELAR (⛔)    │     ❌     │     ❌     │   todos    │   todos    │
│                  │            │            │ s/ limite  │ s/ limite  │
│                  │            │            │            │            │
│ VER TODOS        │     ❌     │  contrato  │   todos    │   todos    │
│ (na consulta)    │            │            │            │            │
└──────────────────┴────────────┴────────────┴────────────┴────────────┘
```

### 5.2 Botões na Tela de Visualização (por Status do OFS)

```
┌──────────────────┬────────────┬────────────┬────────────┐
│ Botão            │  GERADO    │  EDITADO   │ CANCELADO  │
├──────────────────┼────────────┼────────────┼────────────┤
│ 📄 GERAR PDF     │    ✅      │    ✅      │    ✅      │
│ ✏ EDITAR         │  condic.*  │  condic.*  │    ❌      │
│ ⛔ CANCELAR       │  condic.*  │  condic.*  │    ❌      │
│ ↩ VOLTAR         │    ✅      │    ✅      │    ✅      │
└──────────────────┴────────────┴────────────┴────────────┘

* condic. = condicional conforme perfil + prazo de edição/cancelamento
```

### 5.3 Botões na Linha da Tabela de Consulta

```
┌──────────────────┬────────────┬────────────┬────────────┐
│ Ícone            │  GERADO    │  EDITADO   │ CANCELADO  │
├──────────────────┼────────────┼────────────┼────────────┤
│ 👁 Ver           │    ✅      │    ✅      │    ✅      │
│ 📄 PDF           │    ✅      │    ✅      │    ✅      │
│ ✏ Editar         │  condic.*  │  condic.*  │    ❌      │
│ ⛔ Cancelar       │  condic.*  │  condic.*  │    ❌      │
└──────────────────┴────────────┴────────────┴────────────┘
```

### 5.4 Regras de Prazo para Edição

```
┌──────────────────┬──────────────────────────────────────────────┐
│ Perfil           │ Regra de Edição                              │
├──────────────────┼──────────────────────────────────────────────┤
│ Observador       │ Pode editar apenas OFCs que CRIOU,           │
│                  │ em até 24h da data de criação.               │
│                  │ Após 24h, botão ✏ some da linha.            │
│                  │                                              │
│ Supervisor       │ Pode editar OFCs do seu CONTRATO,            │
│                  │ em até 48h da data de criação.               │
│                  │                                              │
│ Gestor / Admin   │ Sem limite de tempo. Pode editar qualquer    │
│                  │ OFS de qualquer empresa/contrato.            │
│                  │                                              │
│ OFS Cancelada    │ NUNCA pode ser editada (nenhum perfil).      │
└──────────────────┴──────────────────────────────────────────────┘
```

### 5.5 Regras para Cancelamento

```
┌──────────────────┬──────────────────────────────────────────────┐
│ Perfil           │ Regra de Cancelamento                        │
├──────────────────┼──────────────────────────────────────────────┤
│ Observador       │ ❌ NÃO pode cancelar (nenhum caso).          │
│                  │                                              │
│ Supervisor       │ ❌ NÃO pode cancelar.                        │
│                  │                                              │
│ Gestor / Admin   │ ✅ Pode cancelar qualquer OFS (exceto as     │
│                  │ já canceladas). Deve informar motivo          │
│                  │ obrigatório (mínimo 10 caracteres).          │
│                  │                                              │
│ OFS Cancelada    │ Botão ⛔ oculto. Não é possível cancelar      │
│                  │ um registro já cancelado.                    │
└──────────────────┴──────────────────────────────────────────────┘
```

### 5.6 Menu Lateral (Sidebar) — Visibilidade por Perfil

```
┌──────────────────────┬────────────┬────────────┬────────────┬────────────┐
│ Item de Menu         │ Observador │ Supervisor │   Gestor   │   Admin    │
├──────────────────────┼────────────┼────────────┼────────────┼────────────┤
│ 📊 Início            │    ✅      │    ✅      │    ✅      │    ✅      │
│ ➕ Nova OFS/OFS      │    ✅      │    ✅      │    ✅      │    ✅      │
│ 🔍 Consulta          │    ✅      │    ✅      │    ✅      │    ✅      │
│ 📈 Métricas          │    ❌      │    ✅      │    ✅      │    ✅      │
│ 📄 Relatórios        │    ❌      │    ❌      │    ✅      │    ✅      │
│ ──────────────────── │ ────────── │ ────────── │ ────────── │ ────────── │
│ 👥 Usuários          │    ❌      │    ❌      │    ❌      │    ✅      │
│ 🏢 Empresas          │    ❌      │    ❌      │    ❌      │    ✅      │
│ 📋 Contratos         │    ❌      │    ❌      │    ❌      │    ✅      │
│ 🎯 Metas             │    ❌      │    ❌      │    ✅      │    ✅      │
│ 📍 Locais            │    ❌      │    ❌      │    ❌      │    ✅      │
│ 🔍 Auditoria         │    ❌      │    ❌      │    ❌      │    ✅      │
│ ──────────────────── │ ────────── │ ────────── │ ────────── │ ────────── │
│ ⚙ Perfil (senha)     │    ✅      │    ✅      │    ✅      │    ✅      │
│ ⏻ Sair               │    ✅      │    ✅      │    ✅      │    ✅      │
└──────────────────────┴────────────┴────────────┴────────────┴────────────┘
```

---

## 6. RESPONSIVIDADE

### 6.1 Breakpoints

```
┌─────────┬──────────┬─────────────────────┬──────────────────────────────────┐
│ Prefix  │ Largura  │ Dispositivo         │ Comportamento                     │
├─────────┼──────────┼─────────────────────┼──────────────────────────────────┤
│  sm     │  ≥640px  │ Mobile landscape    │ 1 coluna, sidebar oculta          │
│  md     │  ≥768px  │ Tablet portrait     │ 2 colunas em forms, sidebar overlay│
│  lg     │ ≥1024px  │ Tablet landscape    │ 2 colunas, sidebar fixa            │
│  xl     │ ≥1280px  │ Desktop             │ Layout máx. 1400px centralizado    │
│ 2xl     │ ≥1536px  │ Desktop ultrawide   │ Igual xl (conteúdo limitado)      │
└─────────┴──────────┴─────────────────────┴──────────────────────────────────┘
```

### 6.2 Tela Nova OFS/OFS — Layout Responsivo

```
Desktop (lg ≥1024px) — 2 colunas:
┌──────────────────────────────────────────────────────┐
│ DADOS AUTOMÁTICOS (full width, cinza)                 │
│                                                       │
│ ┌─────────────────────┐ ┌───────────────────────────┐ │
│ │ Empresa Observada * │ │ Nome do Observado *       │ │
│ └─────────────────────┘ └───────────────────────────┘ │
│ ┌─────────────────────┐ ┌───────────────────────────┐ │
│ │ Atividade *         │ │ Local *                   │ │
│ └─────────────────────┘ └───────────────────────────┘ │
│ ┌─────────────────────┐ ┌───────────────────────────┐ │
│ │ Turno *             │ │ Tipo * (radio)            │ │
│ └─────────────────────┘ └───────────────────────────┘ │
│ ┌───────────────────────────────────────────────────┐ │
│ │ Comportamento Observado * (full width)            │ │
│ └───────────────────────────────────────────────────┘ │
│ ┌───────────────────────────────────────────────────┐ │
│ │ Observação Complementar (full width)              │ │
│ └───────────────────────────────────────────────────┘ │
│                                                       │
│ [💾 SALVAR]  [↩ CANCELAR]                            │
└──────────────────────────────────────────────────────┘

Tablet (md 768-1023px) — 2 colunas compactas:
┌─────────────────────────────────────────────┐
│ ┌────────────────────┐┌───────────────────┐ │
│ │ Empresa Observada *││Nome do Observado *│ │
│ └────────────────────┘└───────────────────┘ │
│ ┌────────────────────┐┌───────────────────┐ │
│ │ Atividade *        ││ Local *           │ │
│ └────────────────────┘└───────────────────┘ │
│ ┌────────────────────┐┌───────────────────┐ │
│ │ Turno *            ││ Tipo * (radio)    │ │
│ └────────────────────┘└───────────────────┘ │
│ Comportamento * (full)                       │
│ Observação (full)                            │
│ [💾 SALVAR] [↩ CANCELAR]                    │
└─────────────────────────────────────────────┘

Mobile (sm <768px) — 1 coluna:
┌──────────────────────────────┐
│ Empresa Observada *          │
│ [______________________▾]   │
│                              │
│ Nome do Observado *          │
│ [______________________]    │
│                              │
│ Atividade Observada *        │
│ [______________________]    │
│                              │
│ Local Observado *            │
│ [______________________]    │
│                              │
│ Turno *                      │
│ [______________________▾]   │
│                              │
│ Tipo da Observação *         │
│ ○ Positivo / Seguro          │
│ ○ Negativo / Inseguro        │
│                              │
│ Comportamento *              │
│ [______________________]    │
│ [______________________]    │
│                              │
│ Observação Complementar      │
│ [______________________]    │
│                              │
│ [   💾 SALVAR REGISTRO   ]   │
│ [     ↩ CANCELAR         ]   │
└──────────────────────────────┘
```

### 6.3 Tela Consulta — Layout Responsivo

```
Desktop (≥1024px): Filtros em grid 4-5 colunas, tabela completa com scroll
Tablet (768-1023px): Filtros em 2-3 colunas, tabela com scroll horizontal
Mobile (<768px):
  - Filtros colapsados (toggle [▼ FILTROS])
  - Tabela vira cards empilhados (cada linha = 1 card)
  - Ações: dropdown [···] ao final do card
```

### 6.4 Tela Visualização — Layout Responsivo

```
Desktop (≥1024px):
  Documento simula folha A4 centralizada (max-w-4xl)
  Grid dados gerais: 2 colunas lado a lado
  Botões de ação: lado a lado

Tablet (768-1023px):
  Documento ocupa 95% da largura
  Grid dados gerais: 2 colunas
  Botões: 2 por linha

Mobile (<768px):
  Documento full-width (sem padding lateral simulando papel)
  Grid dados gerais: 1 coluna (labels acima dos valores)
  Botões empilhados full-width
  Histórico: tabela com scroll horizontal
```

### 6.5 Regras de Toque Mobile

```
┌─────────────────────────────────────────────────────────────┐
│ - Alvo mínimo de toque: 44×44px (WCAG 2.1)                  │
│ - Espaçamento entre botões interativos: mínimo 8px          │
│ - Sem estados hover em touch (usar :active)                 │
│ - Teclado contextual:                                       │
│   · input[type="text"]     → teclado texto                  │
│   · input[type="date"]     → date picker nativo              │
│   · input[type="number"]   → teclado numérico               │
│   · textarea               → teclado texto multiline        │
│ - Swipe down para fechar modais                             │
│ - Sidebar fecha ao clicar fora (overlay)                    │
│ - Pinch-to-zoom desabilitado (meta viewport: scalable=no)   │
│   para evitar zoom acidental em inputs                      │
│ - font-size mínimo 16px em inputs mobile (evita zoom iOS)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. FLUXO DE INTERAÇÃO — REGISTRO DE OFS

### 7.1 Diagrama Sequencial Passo a Passo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     FLUXO COMPLETO: REGISTRAR UMA OFS                        │
│                                                                              │
│  PASSO 1: ACESSAR                                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Tela Início → Botão [+ NOVA OFS/OFS] (destaque primário, central)    │  │
│  │  OU                                                                   │  │
│  │  Sidebar → "+ Nova OFS/OFS"                                           │  │
│  │  OU                                                                   │  │
│  │  Atalho ⌨ Ctrl+N                                                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  PASSO 2: CARREGAR FORMULÁRIO                                                │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ ▶ Carrega em < 1s                                                      │  │
│  │ ▶ Preenche automaticamente:                                            │  │
│  │     · Data atual (readonly)                                            │  │
│  │     · Hora atual (readonly)                                            │  │
│  │     · Nome do usuário logado (readonly)                                │  │
│  │     · Empresa do contrato (readonly)                                   │  │
│  │     · Contrato ativo (readonly)                                        │  │
│  │ ▶ Foco automático no primeiro campo editável: Empresa Observada        │  │
│  │ ▶ Código placeholder: "Gerado ao salvar"                               │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  PASSO 3: EMPRESA OBSERVADA (primeiro campo)                                  │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ ▶ Usuário clica no dropdown — lista as ~15 empresas cadastradas        │  │
│  │ ▶ Digita para filtrar (ex: "sec" → filtra "Security Dynamics")        │  │
│  │ ▶ Seleciona uma empresa                                                │  │
│  │                                                                         │  │
│  │ CENÁRIO ALTERNATIVO: "OUTROS"                                          │  │
│  │ ▶ Usuário seleciona última opção: "Outros"                             │  │
│  │ ▶ Surge campo extra: "Nome da Empresa Observada *" (animação slide)    │  │
│  │ ▶ Usuário digita o nome da empresa externa                             │  │
│  │ ▶ Se voltar para empresa da lista, campo extra some e valor é limpo    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  PASSO 4: PREENCHER DEMAIS CAMPOS                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ ▶ Nome do Observado * → texto livre (pessoa observada)                 │  │
│  │ ▶ Atividade Observada * → texto livre (o que a pessoa fazia)           │  │
│  │ ▶ Local Observado * → texto livre (onde ocorreu)                       │  │
│  │ ▶ Turno * → dropdown: Diurno | Noturno | Misto | Administrativo       │  │
│  │ ▶ Tipo * → radio: ○ Positivo/Seguro  ○ Negativo/Inseguro              │  │
│  │ ▶ Comportamento Observado * → textarea 4 linhas, máx 2000 caracteres  │  │
│  │ ▶ Observação Complementar → textarea 3 linhas, máx 500 caracteres     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  PASSO 5: VALIDAÇÃO INLINE                                                    │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ ▶ Ao perder foco de cada campo (onBlur):                               │  │
│  │     · Campo obrigatório vazio → borda vermelha + msg de erro           │  │
│  │     · Comportamento < 10 caracteres → "Mínimo de 10 caracteres"        │  │
│  │     · Empresa "Outros" sem nome → "Informe o nome da empresa"          │  │
│  │ ▶ Botão SALVAR permanece desabilitado (opacidade 50%)                  │  │
│  │   enquanto houver QUALQUER erro de validação                           │  │
│  │ ▶ Contador de caracteres atualiza em tempo real no textarea            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  PASSO 6: SALVAR                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ ▶ Usuário clica [💾 SALVAR REGISTRO] ou pressiona ⌨ Ctrl+S            │  │
│  │ ▶ Botão muda para [◐ SALVANDO...] com Spinner animado                  │  │
│  │ ▶ Todos os campos são desabilitados (disabled)                         │  │
│  │ ▶ Requisição POST para API local                                       │  │
│  │                                                                         │  │
│  │ SUCESSO (200):                                                          │  │
│  │ ▶ Toast verde no canto superior direito:                                │  │
│  │     "✅ Registro OFS #1523 salvo com sucesso"                          │  │
│  │ ▶ Modal centralizado com número do OFS em destaque                     │  │
│  │ ▶ 3 opções: [👁 Ver registro] [➕ Nova OFS] [↩ Voltar ao início]       │  │
│  │                                                                         │  │
│  │ ERRO (4xx/5xx):                                                         │  │
│  │ ▶ Toast vermelho com mensagem específica                               │  │
│  │ ▶ Campos voltam a ficar editáveis                                      │  │
│  │ ▶ Dados preenchidos são preservados (não perde o que digitou)          │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  PASSO 7: PÓS-SALVAR (opções do usuário)                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                                                                         │  │
│  │  [👁 VER REGISTRO]                                                      │  │
│  │       │                                                                 │  │
│  │       ▼                                                                 │  │
│  │  → Navega para /OFS/:id (Tela de Visualização)                         │  │
│  │  → Vê o documento completo, pode gerar PDF, editar, cancelar            │  │
│  │                                                                         │  │
│  │  [➕ NOVA OFS/OFS]                                                      │  │
│  │       │                                                                 │  │
│  │       ▼                                                                 │  │
│  │  → Reseta todos os campos editáveis                                    │  │
│  │  → Mantém dados automáticos (data/hora atualizados)                    │  │
│  │  → Foco volta para Empresa Observada                                   │  │
│  │  → Usuário pode registrar outra OFS em sequência                       │  │
│  │                                                                         │  │
│  │  [↩ VOLTAR AO INÍCIO]                                                  │  │
│  │       │                                                                 │  │
│  │       ▼                                                                 │  │
│  │  → Navega para / (Dashboard)                                            │  │
│  │  → Cards de indicadores atualizados com o novo registro                 │  │
│  │                                                                         │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Tempo Estimado por Passo

```
┌──────────────────────────────────────────────────────────────┐
│ PASSO │ AÇÃO                          │ TEMPO (seg) │ ACUM.  │
├───────┼───────────────────────────────┼─────────────┼────────┤
│  1    │ Clicar [+ NOVA OFS]           │     2       │   2s   │
│  2    │ Carregar formulário           │     1       │   3s   │
│  3    │ Selecionar Empresa Observada  │     5       │   8s   │
│  4    │ Preencher demais campos       │    45       │  53s   │
│  5    │ Validação automática          │     0       │  53s   │
│  6    │ Clicar Salvar + resposta      │     3       │  56s   │
│  7    │ Escolher ação pós-salvar      │     3       │  59s   │
├───────┼───────────────────────────────┼─────────────┼────────┤
│ TOTAL │                               │    59s      │ < 2min │
└───────┴───────────────────────────────┴─────────────┴────────┘

Meta MVP: tempo médio < 120 segundos (2 minutos) ✓
```

### 7.3 Atalhos de Teclado

```
┌──────────────────────────────────────────────────────────┐
│ TELA NOVA OFS:                                           │
│   Ctrl+S       → Salvar registro                         │
│   Ctrl+N       → Nova OFS (do dashboard)                 │
│   Tab          → Próximo campo                           │
│   Shift+Tab    → Campo anterior                          │
│   Esc          → Cancelar / Voltar                       │
│                                                          │
│ TELA CONSULTA:                                           │
│   Ctrl+F       → Foco no campo de busca/código           │
│   Esc          → Limpar filtros                          │
│   ← →          → Navegar páginas da tabela               │
│                                                          │
│ TELA VISUALIZAÇÃO:                                       │
│   Ctrl+P      → Gerar PDF                                │
│   Esc         → Voltar                                   │
└──────────────────────────────────────────────────────────┘
```

### 7.4 Fluxograma Visual (ASCII)

```
                        ┌─────────┐
                        │ INÍCIO   │
                        │Dashboard │
                        └────┬─────┘
                             │ [+ NOVA OFS/OFS] ou Ctrl+N
                             ▼
                  ┌─────────────────────┐
                  │   NOVA OFS/OFS      │
                  │   (formulário)      │
                  │                     │
                  │  Dados automáticos  │
                  │  [preenchidos]      │
                  └──────────┬──────────┘
                             │ Preenche campos editáveis
                             ▼
                  ┌─────────────────────┐
                  │  VALIDAÇÃO INLINE   │
                  │  (onBlur)           │
                  │                     │
                  │  ┌─────┐  ┌──────┐  │
                  │  │OK ✓ │  │Erro ✗│──┼──→ Corrige campo
                  │  └──┬──┘  └──────┘  │
                  └─────┼───────────────┘
                        │ Todos OK → botão SALVAR habilitado
                        ▼
                  ┌─────────────────────┐
                  │   [💾 SALVAR]       │
                  │   ou Ctrl+S         │
                  └──────────┬──────────┘
                             │ POST /api/OFS
                             ▼
                  ┌─────────────────────┐
                  │   API Response      │
                  └──────┬──────┬───────┘
                         │      │
                    200 OK    4xx/5xx
                         │      │
                         ▼      ▼
              ┌──────────────┐ ┌──────────────┐
              │ TOAST VERDE  │ │ TOAST VERM.  │
              │ + MODAL      │ │ + reabilita  │
              │ SUCESSO      │ │ formulário   │
              └──────┬───────┘ └──────┬───────┘
                     │                │
          ┌──────────┼──────────┐     │
          ▼          ▼          ▼     ▼
    ┌──────────┐┌──────────┐┌──────┐ ┌──────────┐
    │👁 Ver    ││➕ Nova   ││↩ Volt│ │ Corrige  │
    │Registro ││OFS/OFS  ││Início│ │ e tenta  │
    └────┬─────┘└────┬─────┘└──┬───┘ │novamente │
         │           │         │      └──────────┘
         ▼           ▼         ▼
    /OFS/:id    Nova OFS    /
    (Visualiz.) (reset)   (Início)
         │
    ┌────┼────┐
    ▼    ▼    ▼
  [PDF][Editar][Cancelar]
   (se permitido)
```

---

## APÊNDICE: MAPEAMENTO CAMPO → TABELA BD

```
┌──────────────────────────────┬──────────────────────────────┐
│ CAMPO NO FORMULÁRIO          │ COLUNA (ofc_records)         │
├──────────────────────────────┼──────────────────────────────┤
│ Código                       │ sequential_number (gerado)   │
│ Data                         │ observation_date             │
│ Hora                         │ created_at (extrai hora)     │
│ Usuário                      │ observer_id → users.name     │
│ Empresa (contrato)           │ company_id → companies.name  │
│ Contrato                     │ department_id (contexto)     │
│ Empresa Observada            │ company_id (se lista)        │
│                              │ ou observed_name (se Outros) │
│ Nome Empresa (Outros)        │ observed_name (modificado)   │
│ Nome do Observado            │ observed_name                │
│ Atividade Observada          │ activity_context             │
│ Local Observado              │ location                     │
│ Turno                        │ shift                        │
│ Tipo da Observação           │ classification               │
│ Comportamento Observado      │ behavior_description         │
│ Observação Complementar      │ context                      │
│ Status (visualização)        │ status                       │
│ Histórico de edições         │ ofc_edit_log                 │
└──────────────────────────────┴──────────────────────────────┘
```

---

**Versão:** 1.0 | **Autor:** Especialista Frontend/UX | **Data:** 13/05/2026  
**Próxima etapa:** Implementar componentes React + Tailwind conforme especificação acima.
