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
- Upload de arquivos de texto em lote
- Editar e remover textos existentes
- Ver progresso do conteúdo inserido

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
