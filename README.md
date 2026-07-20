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

- **Estrutura de pastas Flutter** feature-first (`app/lib/core/`,
  `app/lib/features/{auth,organizacao,missoes,loja,notificacoes}/`), ver
  `PLANO_MIGRACAO.md` §5.4 — pastas de features ainda vazias, aguardando
  telas/login social
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
- **Código de login social** (`app/lib/features/auth/`): `AuthRepository`
  com `signInWithGoogle`/`signInWithApple` (troca idToken por sessão do
  Supabase via `signInWithIdToken`), `LoginScreen`, e `main.dart` já roteia
  entre login e app autenticado conforme a sessão. `flutter analyze` limpo.
- **Login com Google testado e funcionando ponta a ponta** (simulador iOS):
  clients Web/Android/iOS criados no Google Cloud Console, `webClientId` em
  `app/lib/core/google_auth_config.dart`, `GIDClientID` +
  `REVERSED_CLIENT_ID` no `Info.plist` (iOS), SHA-1 de debug registrado
  (Android), provider Google habilitado no Supabase Dashboard com os Client
  IDs Web *e* iOS na lista (o idToken do iOS usa o client iOS como
  audience, não o Web). `AuthRepository` gera um nonce próprio (hash
  SHA-256 pro Google em `initialize()`, valor cru pro
  `signInWithIdToken()`) — o Supabase rejeita o token se o nonce não
  bater. Sessão autenticada confirmada com conta real.
- **Onboarding de organização nova** (`app/lib/features/organizacao/`):
  `OrganizacaoRepository` busca a linha do usuário em `usuarios` e chama a
  RPC `criar_organizacao`; `OnboardingScreen` pede o nome da família.
  `_AuthGate` (`main.dart`) agora decide entre login → onboarding → app
  autenticado, checando se o usuário logado já tem linha em `usuarios`.
  Testado ponta a ponta no simulador iOS: login sem organização cai na tela
  de onboarding, criar a família ("Família Teste") navega pra home. `flutter
  analyze` limpo.
- **Painel do responsável** — cadastro de missões/prêmios, aprovação de
  comprovações e confirmação de resgates:
  - `app/lib/features/missoes/`: `MissoesRepository`/providers (CRUD de
    `coordenadas_voo` — criar, editar, ativar/desativar) e
    `listarComprovacoesPendentes`/`validarComprovacao` (fila de
    `status = 'enviada'`, aprovar credita moedas via trigger existente,
    rejeitar não). `MissoesScreen`, `MissaoFormScreen`, `ComprovacoesScreen`
    (foto via signed URL do bucket privado `comprovacoes`).
  - `app/lib/features/loja/`: `LojaRepository`/providers (CRUD de
    `suprimentos_cosmicos`) e `confirmarEntrega` (fila de resgates
    `status = 'solicitado'` → `'entregue'`). `PremiosScreen`,
    `PremioFormScreen`, `ResgatesScreen`.
  - **Exclusão** (botão "X", com diálogo de confirmação em
    `core/confirm_delete.dart`), distinta do toggle ativa/inativa: dá pro
    responsável tanto pausar temporariamente uma missão/suprimento quanto
    excluir de vez o que não serve mais. Missão só pode ser excluída com
    `status = 'disponivel'` (RLS nova, migration
    `20260719220000_exclusao_missoes_disponiveis` — uma missão já
    enviada/aprovada não pode ser apagada pra não perder a trilha de moedas
    já creditadas); suprimento com resgate vinculado é bloqueado pela FK
    `on delete restrict` já existente. Testado no simulador iOS: exclusão de
    missão e de suprimento confirmadas funcionando.
  - `_AuthGate` (`main.dart`) agora roteia por `usuario['role']`: responsável
    cai num shell "Comando da Missão" navegado por **menu-sanduíche
    (Drawer)** — trocado de `TabBar` por feedback de usabilidade (rótulos
    longos como "Pedidos do Astronauta" cortavam fora da tela numa TabBar
    scrollável). AppBar mostra a seção atual como título; Drawer lista as 4
    seções com ícone temático cada (Missões/Status das Missões/Suprimentos/
    Pedidos do Astronauta — só os rótulos visíveis mudaram, classes/tabelas
    continuam Comprovações/Prêmios/Resgates internamente); astronauta
    continua no placeholder (painel dele é o próximo passo).
  - Testado ponta a ponta no simulador iOS: cadastro de missão e de
    suprimento confirmados funcionando (CRUD completo, toggle ativo/inativa).
    Fila de "Status das Missões"/"Pedidos do Astronauta" usa o mesmo padrão
    já validado, mas ainda não tem dados reais pra exercitar (depende do
    painel do astronauta enviar comprovação/resgatar suprimento). `flutter
    analyze` limpo.
- **Painel do astronauta** (`app/lib/features/missoes/.../missoes_astronauta_screen.dart`,
  `app/lib/features/loja/.../loja_astronauta_screen.dart` +
  `meus_pedidos_screen.dart`): lista de missões em aberto (atribuídas a ele
  ou abertas pra qualquer um) com envio de comprovação (`image_picker`,
  câmera/galeria — permissões `NSCameraUsageDescription`/
  `NSPhotoLibraryUsageDescription` no `Info.plist`), loja com saldo de
  moedas e resgate (débito atômico via trigger existente), e "Meus Pedidos"
  com status do resgate. Testado ponta a ponta no simulador iOS (alternando
  o `role` da conta de teste via REST API + service role key, já que o app
  só tem login social): cadastro → comprovação com foto → aprovação com
  foto visível (signed URL) → crédito de moedas confirmado (saldo 0 → 4);
  resgate → débito atômico confirmado (saldo 4 → 1) → confirmação de
  entrega pelo responsável. `flutter analyze` limpo.
- **Atribuição de missão/suprimento a um astronauta específico**: até então
  todo item era "aberto pra qualquer um" (`atribuido_a` nulo); agora dá pra
  atribuir a uma criança específica (ex.: recompensa combinada só com um
  filho) — campo "Atribuir a" nos formulários de missão e suprimento.
  `suprimentos_cosmicos` ganhou a coluna `atribuido_a` (espelhando
  `coordenadas_voo`, migration
  `20260720000000_atribuicao_suprimentos_por_astronauta`), com guard no
  trigger `processar_resgate_suprimento` pra rejeitar resgate de suprimento
  reservado pra outro astronauta. Painel do astronauta (missões e loja) já
  filtra pelo que é dele ou aberto.
- **Seletor de criança no painel do responsável**: com até 3
  astronautas por família, o Drawer do "Comando da Missão" ganhou uma
  **dropdown** no topo ("Vendo: Visão geral" / nome + saldo de cada
  astronauta) — `criancaSelecionadaProvider` guarda a seleção e persiste
  entre trocas de tela (não precisa reselecionar a cada aba). Com uma
  criança selecionada, as 4 telas (Missões/Status/Suprimentos/Pedidos)
  filtram só o que é dela. AppBar agora mostra **duas linhas**: título da
  seção (Missões, Suprimentos...) em cima, "Visão geral" ou "nome · saldo"
  embaixo como subtítulo — corrigido depois do feedback de que só trocar o
  título inteiro perdia o contexto de qual seção estava aberta. Também
  corrigido um bug clássico do Flutter: `DropdownButtonFormField` sem
  `key` só lê `initialValue` na primeira montagem e não ressincroniza com
  o provider depois — resolvido com `key: ValueKey(criancaId)`. Testado no
  simulador iOS com dois usuários de teste permanentes
  (`astronauta1@astronauta1.com` / `astronauta2@astronauta2.com`, criados
  via Admin API — não conseguem logar pelo app de verdade, só populam dado
  pra teste; **apagar antes de publicar**).
- **Nomenclatura temática do painel do astronauta**: "Painel de Voo" (era
  "SpaceRout" genérico) — ecoa `coordenadas_voo`, contrasta com "Comando da
  Missão" do responsável (ele comanda de fora, a criança pilota de dentro).
  Seções: "Missões" / "Suprimentos" (era "Loja" — alinhado com o nome do
  responsável) / "Status dos Suprimentos" (era "Meus Pedidos" — evita a
  palavra "aprovado", já que resgate não tem etapa de aprovação, só
  confirmação de entrega).

### 🚧 Em aberto

- [ ] **Antes de publicar**: apagar os usuários de teste
      `astronauta1@astronauta1.com` / `astronauta2@astronauta2.com`
      (`auth.users` + `usuarios`) e a organização "Família Teste" usada
      pra desenvolvimento
- [ ] **Sign in with Apple**: adiado — precisa de conta paga no Apple
      Developer Program, que o usuário ainda não tem. O botão de Apple já
      existe na `LoginScreen` (só aparece em iOS/macOS) mas vai dar erro se
      tocado antes da capability estar configurada. Retomar quando a conta
      sair:
  - [ ] Apple Developer: habilitar capability "Sign in with Apple" no App ID
        e no projeto Xcode (Signing & Capabilities), gera o entitlements
        automaticamente
  - [ ] Supabase Dashboard → Authentication → Providers: habilitar Apple,
        colando o Client ID/Service ID criado
  - [ ] Antes de submeter à App Store: obrigatório por regra da Apple
        sempre que Google Sign-In é oferecido em iOS (ver
        PLANO_MIGRACAO.md §5) — não bloqueia desenvolvimento, só submissão
- [ ] **Push notifications (infra)**: job `pg_cron` + Edge Function que
      dispara via FCM quando `notificar_as` vence. Schema já pronto; falta
      deploy da Edge Function (Deno) + credenciais de service account do
      Firebase
- [ ] **Telas** — portar do protótipo, uma feature por vez:
  - [x] Auth / onboarding de organização nova
  - [x] Painel do responsável (cadastro de missões e prêmios, aprovação de
        comprovação, confirmação de resgate)
  - [x] Painel do astronauta (lista de missões, envio de comprovação, loja,
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
      features/
        auth/          # login social (Google/Apple)
        organizacao/   # onboarding de organização nova
        missoes/       # cadastro de missões + aprovação de comprovações
        loja/          # cadastro de prêmios + confirmação de resgates
      main.dart        # _AuthGate: login → onboarding → painel por role
```
