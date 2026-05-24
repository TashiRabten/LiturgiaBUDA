# LiturgiaBUDA 🙏

App de liturgia budista diária baseado no modelo do iLiturgia, adaptado para a tradição Tibetana sob orientação do Mestre.

---

## Visão Geral

O LiturgiaBUDA organiza as práticas diárias em **4 sessões por dia** (manhã, tarde, noite e madrugada) distribuídas ao longo de **2 fluxos anuais** de leitura e contemplação.

---

## Fluxos de Prática

### Fluxo Principal — 12 meses (360 dias)
Dividido em 3 períodos de 4 meses (120 dias cada):

| Período | Tema | Duração |
|---|---|---|
| 1º (meses 1–4) | Espírito da Renúncia | 120 dias |
| 2º (meses 5–8) | Bodhicitta Aspirativa | 120 dias |
| 3º (meses 9–12) | Bodhicitta Última | 120 dias |

### Fluxo Prajnaparamita — 365 dias
Texto contínuo da Prajnaparamita ao longo do ano inteiro, dividido em 4 sessões por dia.

> **Futuro:** Fluxo Vajrayana (mesmo modelo lógico)

---

## Estrutura de Cada Sessão

Toda sessão — manhã, tarde, noite ou madrugada — segue esta estrutura:

1. **Prece de Refúgio** *(abertura — fixa)*
2. **Sutra Invitatório** *(escolha entre 3 opções)*
   - Sutra das Três Joias
   - Sutra do Coração
   - Dhammacakkappavattanasutta
3. **Leitura do dia** *(varia por fluxo, período e dia)*
4. **Sadhana Ganden Lha Gyalma** *(opcional — sempre acessível)*
5. **Prece Dedicatória** *(encerramento — fixa)*

---

## Telas do App

| Tela | Função |
|---|---|
| Home | Data atual, sessão do dia, fluxo ativo, período |
| Leitura | Exibe a sessão completa em sequência |
| Índice | Acesso a todos os sutras e textos fixos |
| Sadhana | Ganden Lha Gyalma sempre disponível |
| Calendário | Progresso anual, dias completados |
| Configurações | Fluxo ativo, notificações, fonte, modo noturno |
| Admin *(oculto)* | 3 toques no logo — painel da secretaria |

---

## Painel Admin (Secretaria)

Acessado com **3 toques no logo** da tela inicial.  
Login com email + senha via Supabase Auth.

Funções:
- Inserir textos por fluxo / período / dia / sessão
- Upload de arquivos em lote (.pdf, .docx, .txt)
- Editar e remover textos existentes
- Ver progresso do conteúdo inserido

### Upload em Lote — Convenções de Nome

**Destino: Leituras** (tabela `textos`)
```
{dia}_{sessao}.{ext}
```
Exemplos: `001_manha.pdf`, `045_noite.docx`, `230_madrugada.txt`

**Destino: Textos Fixos** (tabela `textos_fixos`)
```
{tipo}_{nome}.{ext}
```
Tipos válidos: `refugio`, `dedicatoria`, `invitatório`, `sutra`, `sadhana`

Exemplos:
- `refugio_principal.pdf` → Prece de Refúgio
- `dedicatoria_padrao.docx` → Prece Dedicatória
- `sutra_coracao.pdf` → Sutra do Coração
- `sutra_tresjoias.pdf` → Sutra das Três Joias
- `sadhana_gandenlhagyalma.docx` → Ganden Lha Gyalma

### Extração de Conteúdo

| Formato | Preserva formatação? | Como |
|---|---|---|
| `.docx` | ✅ Sim | Parse XML — negrito, itálico, headings → Markdown |
| `.pdf`  | ⚠️ Parcial | Texto puro com parágrafos; sem bold/itálico confiável |
| `.txt`  | ❌ Não | Texto cru |

O conteúdo é salvo em **Markdown** na coluna `conteudo` e renderizado com `markdown_widget` na tela de leitura.

### Constraints únicas necessárias no Supabase

Para upload com substituição (re-upload do mesmo arquivo atualiza ao invés de duplicar):

```sql
alter table public.textos
  add constraint textos_fluxo_periodo_dia_sessao_unique
  unique (fluxo_id, periodo, dia, sessao);

alter table public.textos_fixos
  add constraint textos_fixos_tipo_nome_unique
  unique (tipo, nome);
```

---

## Arquitetura Técnica

```
Supabase (nuvem)
    ↓ download apenas
App Flutter — SQLite local
    ↓ leitura
Usuário
```

### Stack
- **Frontend:** Flutter (Dart) — Windows, macOS, Android, iOS
- **Banco local:** SQLite via `sqflite`
- **Nuvem:** Supabase (PostgreSQL + Auth + Storage)
- **Sync:** Download incremental por `updated_at`
- **Admin:** Tela oculta dentro do app (3 toques no logo)

### Tabelas Supabase

| Tabela | Conteúdo |
|---|---|
| `fluxos` | Fluxo principal e Prajnaparamita |
| `textos` | Leituras por fluxo / período / dia / sessão |
| `textos_fixos` | Refúgio, dedicatória, sutras invitatórios, sadhana |
| `app_metadata` | Versão do conteúdo para controle de sync |

### Segurança
- Usuários do app usam `anon key` — só leitura (RLS ativo)
- Admin usa `authenticated` com email autorizado
- Chaves nunca commitadas no GitHub (`lib/config/keys.dart` no `.gitignore`)

---

## Plataformas

| Plataforma | Status | Build |
|---|---|---|
| Windows | ✅ Em desenvolvimento | `.exe` |
| macOS | 🔄 Build na VM Mac | `.pkg` |
| Android | 🔜 Futuro | `.apk` |
| iOS | 🔜 Futuro | `.ipa` |

---

## Roadmap

- [ ] Estrutura do banco SQLite local
- [ ] Conexão com Supabase (sync básico)
- [ ] Tela Home com sessão do dia
- [ ] Tela de Leitura (sequência completa)
- [ ] Painel Admin (3 toques no logo)
- [ ] Notificações por horário de sessão
- [ ] Índice de sutras
- [ ] Calendário de progresso
- [ ] Build Windows `.exe`
- [ ] Build macOS `.pkg`
- [ ] Android / iOS (fase 2)

---

## Estrutura de Pastas

```
lib/
├── config/
│   └── keys.dart          # Supabase keys (NÃO commitado)
├── models/
│   ├── fluxo.dart
│   ├── texto.dart
│   └── texto_fixo.dart
├── services/
│   ├── database_service.dart
│   ├── supabase_service.dart
│   └── sync_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── leitura_screen.dart
│   ├── indice_screen.dart
│   ├── sadhana_screen.dart
│   ├── calendario_screen.dart
│   ├── configuracoes_screen.dart
│   └── admin/
│       ├── login_screen.dart
│       └── admin_screen.dart
└── main.dart
```

---

*Conteúdo fornecido pelo Mestre — textos inseridos pela secretaria via painel admin.*
