# SpaceRout

App de gamificação de tarefas domésticas para famílias: responsáveis cadastram
missões e prêmios, crianças ("astronautas") cumprem missões, ganham moedas e
trocam por prêmios. Nasceu como protótipo em Streamlit/Google Sheets
(congelado em [`SpaceRout-Streamlit`](https://github.com/diogodcg/SpaceRout),
pasta irmã deste repo) e está sendo reconstruído aqui como produto real:
apps nativos iOS/Android em Flutter, backend em Supabase.

> Decisões de arquitetura e o raciocínio por trás delas (o "porquê") estão em
> [`PLANO_MIGRACAO.md`](./PLANO_MIGRACAO.md). Este README é só o mapa de
> **onde estamos** — atualize o checklist abaixo a cada etapa concluída.

## Stack

| Camada | Escolha |
|---|---|
| Banco + backend | Supabase (Postgres + Auth + RLS + Storage) |
| Frontend mobile | Flutter (`app/`), Riverpod, `supabase_flutter` |
| Push notifications | Firebase Cloud Messaging |
| Assinatura | RevenueCat (IAP App Store / Play Store) |

Projeto Supabase: `SpaceRout` (ref `kzizdekhohisnixyzlqj`). CLI local já
linkado — `supabase db push` aplica migrations pendentes direto.

## Estado atual

### ✅ Feito

- **Schema do banco** (`supabase/migrations/`), todas aplicadas no projeto remoto:
  - `organizacoes_familiares`, `usuarios`, `coordenadas_voo` (missões),
    `suprimentos_cosmicos` (loja), RLS completo, trava freemium (5 itens
    ativos no plano gratuito)
  - `resgates_suprimentos` (histórico de resgate com débito atômico de
    saldo), RPC `enviar_comprovacao_missao`
  - Onboarding (RPC `criar_organizacao`), convites completos com aceite
    automático no primeiro login, `unique` em `usuarios.email`, correção de
    RLS (astronauta não atualiza `coordenadas_voo` direto), colunas de
    notificação (`notificar_as` etc.) + tabela `dispositivos_notificacao`,
    bucket privado `comprovacoes` no Storage
- **Esqueleto Flutter** (`app/`): projeto criado, `supabase_flutter` +
  `flutter_riverpod` instalados, `main.dart` inicializa o client e mostra
  tela de conexão OK

### 🚧 Em aberto

- [ ] **Push notifications (infra)**: job `pg_cron` + Edge Function que
      dispara via FCM quando `notificar_as` vence. Schema já pronto; falta
      deploy da Edge Function (Deno) + credenciais de service account do
      Firebase
- [ ] **Estrutura de pastas Flutter** feature-first (`core/`,
      `features/{auth,organizacao,missoes,loja,notificacoes}/`), ver
      `PLANO_MIGRACAO.md` §5.4
- [ ] **Login social** (Google Sign-In + Sign in with Apple)
- [ ] **Telas** — portar do protótipo, uma feature por vez:
  - [ ] Auth / onboarding de organização nova
  - [ ] Painel do responsável (cadastro de missões e prêmios, aprovação de
        comprovação)
  - [ ] Painel do astronauta (lista de missões, envio de comprovação, loja,
        resgate)
  - [ ] Fluxo de convite (responsável convida, astronauta/segundo
        responsável aceita)
- [ ] **Assinatura**: integração RevenueCat + Edge Function que atualiza
      `organizacoes_familiares.plano`/`plano_expira_em`

## Estrutura do repo

```
spacerout/
  PLANO_MIGRACAO.md   # decisões de arquitetura e o porquê de cada uma
  supabase/
    migrations/        # schema, aplicado via `supabase db push`
  app/                 # projeto Flutter
    lib/
      core/            # client Supabase, config
      main.dart
```
