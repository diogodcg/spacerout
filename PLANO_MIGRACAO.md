# SpaceRout — Plano de migração (Streamlit/Sheets → Flutter/Supabase)

> Documento de trabalho para revisão. Reflete as decisões tomadas até agora;
> os itens marcados como **em aberto** ainda não foram desenhados/decididos.

## 1. Contexto

O protótipo atual (Streamlit + Google Sheets, descrito no `README.md`) foi
um PoC/teste pessoal. A ideia agora é transformar o SpaceRout em um produto
para mercado, com apps nativos para iOS e Android.

O protótipo continua servindo de **especificação funcional**: toda a lógica
de negócio (roles, missões, moedas, loja de prêmios, notificações) já está
validada nele e é a referência para o schema novo.

## 2. Stack decidida

| Camada | Escolha | Por quê |
|---|---|---|
| Banco + backend | **Supabase** (Postgres + Auth + RLS + Storage + Realtime) | Cobre auth, banco relacional e autorização (RLS) sem precisar manter um servidor de API à parte. Lógica crítica (saldo de moedas, limite freemium) já fica em triggers/functions no próprio banco. |
| Frontend mobile | **Flutter** (Dart), pacote `supabase_flutter` | Um único código para iOS + Android, performance próxima de nativo, ecossistema maduro de integração com Supabase. Alternativa descartada: apps nativos separados (Swift/Kotlin) — dobraria o esforço de dev/manutenção sem necessidade clara de API nativa específica. |
| Backend custom (se necessário) | Supabase Edge Functions (TypeScript/Deno) | Só entra se surgir lógica que não cabe em função/trigger do Postgres. Não há servidor Node separado. |
| Ferramental de dev | Supabase CLI (via npm ou Homebrew) | Só para rodar migrations localmente e gerenciar o projeto Supabase. Não faz parte do runtime do app. |
| Notificações push | **Firebase Cloud Messaging (FCM)** | Decidido para o v1 (ver seção 5.1) — cobre Android nativamente e iOS via APNs por baixo. Descartada a alternativa de um provedor por cima (ex.: OneSignal): FCM direto é suficiente pro escopo e evita mais uma dependência externa. |
| Descartado | Streamlit, Google Sheets, `st-gsheets-connection`, `requirements.txt` atual | Serviram de PoC; serão aposentados por completo. |

**Nota sobre linguagem:** a dúvida inicial era Python "vs." algo mais
"profissional" — mas o verdadeiro limitador nunca foi a linguagem, e sim o
Streamlit em si (feito para dashboards internos, não para apps de loja).
Com Flutter, resolve-se tanto a questão de rodar em iOS/Android quanto a de
usar uma stack de mercado.

## 3. Schema Supabase — já implementado

Arquivo: `supabase/migrations/20260718000000_initial_schema.sql`

### 3.1 Extensões
- `pgcrypto` — usado para `gen_random_uuid()`. Não é estritamente necessário
  (Postgres 13+ já tem `gen_random_uuid()` no core) e o Supabase já vem com
  ele disponível por padrão. Nenhuma outra extensão é usada no schema.

### 3.2 Tipos enumerados
- `user_role`: `responsavel` | `astronauta`
- `plano_tipo`: `gratuito` | `anual`
- `recorrencia_tipo`: `diaria` | `semanal` | `pontual`
- `missao_status`: `disponivel` | `enviada` | `aprovada` | `rejeitada`

### 3.3 Tabelas

| Tabela | Papel | Observações |
|---|---|---|
| `organizacoes_familiares` | Tenant (uma família = uma organização) | Não existia no protótipo (que atendia só uma família via planilha única). Base da multi-tenancy. Controle de plano e expiração. |
| `usuarios` | Perfil de app, 1:1 com `auth.users` | Sem coluna de senha (autenticação é do Supabase Auth). Guarda `role`, `saldo_moedas` (mantido por trigger), `is_platform_admin`. |
| `coordenadas_voo` | Missões/tarefas | Equivalente a `tarefas_historico`: uma linha por ciclo de missão (nunca reescreve, cria linha nova a cada ciclo) — preserva histórico e permite auditar/recalcular saldo. |
| `suprimentos_cosmicos` | Itens da loja de prêmios | Equivalente a `premios_cadastro`. |

### 3.4 Triggers / funções
- `verificar_limite_freemium` — trava de no máx. 5 itens ativos (missões OU
  prêmios) por organização no plano gratuito. Requisito de negócio novo, não
  existia no protótipo.
- `aplicar_moedas_aprovadas` — incrementa `usuarios.saldo_moedas` quando uma
  `coordenada_voo` passa a `aprovada` (só na transição, evita duplicar).
- Helpers de RLS (`security definer`): `minha_organizacao_id()`,
  `meu_role()`, `sou_platform_admin()`.

### 3.5 RLS
Habilitado nas 4 tabelas, com policies por role (`responsavel` cria/edita
missões e prêmios da própria organização; `astronauta` só atualiza
missões atribuídas a ele; leitura restrita à própria organização).

## 4. Lacunas conhecidas (sinalizadas no próprio SQL)

1. **Histórico de resgate de prêmios** (`premios_historico` no protótipo)
   — ainda não modelado. Fica para uma próxima migration.
2. **RLS controla linha, não coluna**: a policy de update de
   `coordenadas_voo` permite que um astronauta atualize a linha atribuída a
   ele (para enviar comprovação), mas não impede a nível de banco que ele
   altere o campo `moedas` em vez de só `status`/`foto_url`. Precisa de uma
   função RPC dedicada (ou checagem na app) antes de ir para produção.
3. **Sem noção de "prazo" na missão**: `coordenadas_voo` guarda `recorrencia`
   (diária/semanal/pontual) mas não tem horário/prazo-limite — falta pra
   saber *quando* disparar um lembrete de missão pendente (ver 5.1).
4. **Sem tabela de device tokens**: notificação push exige guardar o token
   FCM de cada dispositivo por usuário (1 usuário pode ter mais de um
   dispositivo); essa tabela ainda não existe no schema.
5. **`usuarios.email` sem constraint `unique`**: necessário pro fluxo de
   convite (seção 5.2) detectar, na hora de criar o convite, se o e-mail já
   pertence a outra organização.

## 5. Decisões de negócio (autenticação e cobrança)

- **Autenticação**: login social via **Google** e **Sign in with Apple**
  (não usuário/senha). Pressuposto: a partir de ~10 anos a criança já tem
  celular próprio (mesmo sob supervisão dos pais), então cada membro da
  família loga com sua própria conta Google/Apple.
  - No iOS, oferecer Google Sign-In obriga (regra da App Store) a também
    oferecer Sign in with Apple — os dois entram juntos.
- **Cobrança por família, não por dispositivo**: o responsável assina uma
  vez (via IAP da App Store/Play Store — aceitando o corte das lojas, já
  embutido no valor líquido) e cadastra os e-mails dos demais membros da
  família, que passam a ter acesso pela mesma assinatura ao fazer login.
  - Isso exige um **fluxo de convite**: responsável cadastra e-mail →
    usuário convidado, ao logar com aquele e-mail (Google/Apple), é
    vinculado à `organizacao_familiar` que o convidou, em vez de criar uma
    organização nova.
  - Também exige **validar o recibo da assinatura** vindo da loja para
    ativar/renovar `organizacoes_familiares.plano` e `plano_expira_em`.
    **Decidido: RevenueCat** (abstrai App Store + Play Store, tem
    integração pronta com Supabase) — menos código pra manter, mesmo
    sendo mais uma dependência externa com custo próprio acima de certo
    volume. Descartada a alternativa de tratar os webhooks nativos (App
    Store Server Notifications / Play Real-time Developer Notifications)
    direto numa Edge Function — mais trabalho de implementação/manutenção
    sem necessidade clara no momento.

## 5.1 Notificações de missão pendente — requisito do v1

**Decisão**: diferente do protótipo (que só manda e-mail e é facilmente
ignorado), o app mobile precisa de **push notification via FCM já na
primeira versão** — não é "nice to have" pra depois. Motivação: a maior dor
relatada é a criança esquecer de fazer a missão; e-mail não resolve isso
(criança não olha e-mail). Isso é o suficiente pra puxar a decisão de stack
de push pra dentro do v1 em vez de deixar em aberto (ver tabela da seção 2).

**Decidido: horário por missão.** O responsável define um horário de
lembrete ao cadastrar cada missão (ex.: "escovar dentes" às 20h, "arrumar a
cama" às 8h) — campo novo `notificar_as` (time) em `coordenadas_voo`. Mais
flexível que um horário único por família e mais natural que um cálculo
automático (X horas antes da meia-noite), que não faz sentido pra missões
com horário próprio. Custo aceito: mais um campo na tela de cadastro de
missão.

**Decidido: `pg_cron` + Edge Function.** Um job `pg_cron` roda periodicamente
(ex.: a cada minuto/poucos minutos) e chama uma Edge Function que varre
`coordenadas_voo` em busca de missões com `notificar_as` vencido e ainda
`disponivel`, buscando os device tokens dos astronautas atribuídos e
disparando via FCM. Descartado um scheduler externo — foge do "sem servidor
à parte" da seção 2, e `pg_cron` já é nativo do Supabase.

**Decidido: escalonamento pro responsável, sem reenvio ao filho.** Um único
lembrete ao astronauta em `notificar_as`; se a missão continuar
`disponivel` após um prazo de tolerância (default sugerido: 2h — ajustável
depois de uso real), uma segunda notificação avisa o responsável que aquela
missão específica não foi feita. Descartado reenviar ao próprio filho pelo
mesmo canal: retorno decrescente (se a notificação já passou despercebida,
repetir no mesmo canal tende a virar ruído) e o ponto forte do app é dar
visibilidade ao responsável pra cobrar pessoalmente, não insistir por push.

Implementação: reaproveita o job `pg_cron` + Edge Function da seção
anterior. Precisa de um campo (ex.: `lembrete_enviado_em` /
`escalonado_em` em `coordenadas_voo`) pra cada etapa disparar só uma vez.

Ainda em aberto sobre a *implementação* (não sobre nenhuma das decisões
acima): escrever de fato o schema — `notificar_as`, `lembrete_enviado_em`,
`escalonado_em` em `coordenadas_voo` (lacuna 4.3) e a tabela de device
tokens por usuário (lacuna 4.4) — numa próxima migration.

## 5.2 Fluxo de convite

Contexto: cobrança é por família (seção 5), então um e-mail convidado
precisa entrar na `organizacao_familiar` de quem convidou em vez de criar
uma organização nova ao logar pela primeira vez.

**Decidido — tabela `convites`:** `id`, `organizacao_id`, `email`, `role`
destinado (`responsavel` ou `astronauta` — cobre tanto convidar a criança
quanto um segundo responsável na mesma família), `status`
(`pendente` / `aceito` / `expirado` / `cancelado`), `criado_por`,
`expira_em`, `created_at`, `aceito_em`.

**Decidido — aceite via trigger em `auth.users`:** ao logar pela primeira
vez (novo `auth.users`), um trigger `security definer` verifica se existe
convite `pendente` e não expirado pro e-mail que acabou de logar. Se
existe: cria a linha em `usuarios` já vinculada à `organizacao_id`/`role`
do convite, marca o convite como `aceito`. Se não existe: o trigger não faz
nada — o app detecta "logado mas sem linha em `usuarios`" e direciona pro
onboarding de organização nova (seção 5.3).

**Decidido — expiração: 7 dias.** Convite não aceito em 7 dias vira
`expirado` e deixa de valer; o responsável pode reenviar (novo convite pro
mesmo e-mail). Evita convites "zumbi" pendentes indefinidamente.

**Decidido — e-mail já vinculado a outra organização: bloqueado na
criação do convite, não na aceitação.** Como hoje um `usuario` pertence a
uma única `organizacao_id` (sem tabela de junção many-to-many), permitir
esse cadastro geraria um estado ambíguo. Ao responsável tentar convidar um
e-mail que já existe em `usuarios` (de outra organização), o cadastro do
convite falha na hora, com mensagem clara — mais simples que descobrir o
conflito só no momento do login. Exige constraint `unique` em
`usuarios.email` (hoje nullable sem índice único — nova lacuna de schema,
a somar à seção 4).

Ainda em aberto: o que fazer se duas famílias convidarem o mesmo e-mail
simultaneamente antes de qualquer aceite (edge case raro, não bloqueia o
v1 — primeiro aceite vence, o outro convite fica pendente/expira sozinho).

## 5.3 Onboarding de organização nova

Cobre o caso oposto ao convite (5.2): alguém loga pela primeira vez sem
nenhum convite pendente pro seu e-mail — precisa criar a própria família do
zero.

**Decidido — não é automático no trigger, é um passo explícito no app.**
Ao contrário do aceite de convite (que não precisa de nenhuma decisão do
usuário — o convite já traz organização e role prontos), criar uma
organização nova precisa de pelo menos um dado novo (o nome da família), e
criar isso silenciosamente com um nome-placeholder no trigger de
`auth.users` daria uma experiência ruim. Fluxo: login → app detecta que o
`auth.uid()` não tem linha em `usuarios` e não havia convite pendente →
mostra uma tela simples pedindo o nome da família → chama uma RPC
`criar_organizacao(nome text)`.

**Decidido — a RPC faz as duas coisas numa transação só:** cria
`organizacoes_familiares` (`nome` = input, `plano = 'gratuito'`) e a linha
em `usuarios` do chamador com `role = 'responsavel'` (primeiro usuário de
uma família nova é sempre o responsável — é ele quem depois convida os
demais, seção 5.2) e `organizacao_id` apontando pra organização recém-criada.

**Decidido — começa no plano gratuito, sem paywall antes de criar a
família.** O schema já modela o freemium (trava de 5 itens ativos, seção 3.4),
então não há necessidade de forçar assinatura antes de deixar a família
começar a usar o app. Upgrade pra `anual` acontece depois, num fluxo de
assinatura separado (IAP → RevenueCat → Edge Function atualiza `plano` e
`plano_expira_em`, já coberto na seção 5) — nenhuma decisão nova aqui, só
confirma que esse é o ponto de entrada natural pro plano gratuito.

## 5.4 Estrutura do projeto Flutter

**Decidido — gerenciamento de estado: Riverpod.** Padrão atual da
comunidade Flutter (sucessor espiritual do Provider, mesmo autor), menos
boilerplate que Bloc, forte em código async — combina bem com
streams/futures do `supabase_flutter` — e testável sem depender de
`BuildContext`. Descartado Bloc (verboso demais pra um app solo/MVP) e
Provider (mais simples, mas menos poderoso em casos async/complexos).

**Decidido — organização de pastas por funcionalidade (feature-first),
não genérica.** Em vez de agrupar por tipo técnico (`screens/`, `widgets/`,
`models/` soltos na raiz — onde uma pasta `widgets/` acaba virando um
apanhado de 40+ arquivos sem relação entre si), cada funcionalidade mora
numa pasta própria com suas telas/estado/modelos por dentro. Mapeia
1:1 com os domínios já modelados no schema (seção 3), o que facilita achar
o código relacionado a uma tabela:

```
lib/
  core/            # tema, router, client Supabase, utils e widgets
                    # genéricos reaproveitados entre features
  features/
    auth/          # login social (Google/Apple)
    organizacao/   # convites (5.2) e onboarding de família nova (5.3)
    missoes/       # coordenadas_voo — cadastro, painel do responsável,
                    # painel do astronauta
    loja/          # suprimentos_cosmicos — cadastro e resgate
    notificacoes/  # registro de device token, handling de push (5.1)
  main.dart
```

Cada pasta dentro de `features/` segue a mesma divisão interna (ex.:
`data/`, `domain/`, `presentation/`) — a decisão aqui é só sobre o nível
mais alto (por feature), a divisão fina interna de cada feature fica pra
quando o código for escrito.

## 5.5 Fechamento das lacunas do schema (seção 4)

### 5.5.1 Histórico de resgate de prêmios

Levantado no protótipo (`pages/2_Painel_da_Criança.py`,
`pages/1_Painel_do_Responsável.py`): moedas são debitadas **na hora do
resgate** — `calcular_saldo` subtrai o custo de todo resgate, independente
do status de entrega. A entrega (`status_entrega`: `pendente`/`entregue`,
confirmada depois pelo responsável) é só o registro de que o prêmio físico
foi de fato entregue, sem afetar saldo.

**Decidido — nova tabela `resgates_cosmicos`** (mesmo padrão de nome
temático de `suprimentos_cosmicos`): `id`, `organizacao_id`,
`suprimento_id` (FK `suprimentos_cosmicos`), `solicitado_por` (FK
`usuarios`, o astronauta), `custo_moedas` (snapshot do preço no momento do
resgate — o preço do prêmio pode mudar depois sem afetar resgates já
feitos), `status_entrega` (novo enum `entrega_status`: `pendente` |
`entregue`), `data_resgate`, `entregue_por` (FK `usuarios`, o responsável),
`data_entrega`.

**Decidido — débito de moedas imediato via trigger**, espelhando o
protótipo: `aplicar_moedas_resgate` (`after insert`) decrementa
`usuarios.saldo_moedas` na hora do resgate, não na confirmação de entrega.

**Decidido — validação de saldo suficiente movida pro banco.** No
protótipo essa checagem é só client-side (botão desabilitado, mas nada
impede um POST direto). O trigger passa a rejeitar o insert se
`custo_moedas > saldo_moedas` do solicitante — mesmo padrão defensivo já
usado na trava freemium (seção 3.4).

**RLS**: astronauta insere resgate pra si mesmo (`solicitado_por =
auth.uid()`); leitura restrita à própria organização; só responsável marca
`status_entrega = 'entregue'` (`entregue_por`/`data_entrega`).

### 5.5.2 RPC dedicada para envio de comprovação

Fecha a lacuna 4.2 (RLS controla linha, não coluna).

**Decidido**: função `enviar_comprovacao(missao_id uuid, foto_url text)`,
`security definer`, substitui o UPDATE direto do astronauta em
`coordenadas_voo`. A policy de UPDATE passa a permitir só `responsavel`
(astronauta deixa de conseguir dar UPDATE direto na linha); pra enviar
comprovação, astronauta só consegue passando pela RPC, que:
1. Confirma que a missão existe, está `disponivel` e pertence à
   organização do chamador.
2. Confirma que `atribuido_a` é `null` (missão aberta) ou é o próprio
   chamador — se `null`, a missão é "reivindicada" nesse momento
   (`atribuido_a := auth.uid()`), preservando o comportamento atual de
   missões sem atribuição específica.
3. Atualiza só `status = 'enviada'`, `foto_url`, `enviado_por = auth.uid()`,
   `data_envio = now()` — nunca toca em `moedas`.

### 5.5.3 Bucket de Storage pra foto de comprovação

**Decidido — bucket privado (`comprovacoes`), com URL assinada.** Evita
expor fotos (que podem envolver a rotina/quarto da criança) via link
público permanente; custo aceito é gerar uma signed URL de curta duração
toda vez que a foto for exibida no painel do responsável. Descartado bucket
público pelo mesmo motivo de privacidade levantado em 5.1/5.2 pra dados de
criança.

**Decidido — caminho: `{organizacao_id}/{missao_id}.{ext}`.** Policies do
Storage (`storage.objects`) usam o helper `minha_organizacao_id()` já
existente (seção 3.4) pra restringir INSERT/SELECT à própria organização.
A autorização fina (se aquela missão específica pertence ao astronauta que
está enviando) fica por conta da RPC `enviar_comprovacao` (5.5.2), que é o
que efetivamente muda o status da missão — o upload em si só precisa
respeitar o isolamento por organização.

## 6. Em aberto (ainda por refletir)

Nenhum item restante — todas as decisões de produto/arquitetura deste
levantamento foram fechadas (seções 5–5.5). O que falta agora é
implementação (seção 7).

## 7. Próximos passos sugeridos

1. Escrever numa nova migration tudo o que ficou decidido em 5.2–5.5:
   tabela `convites` + trigger de aceite, RPC `criar_organizacao`, campos
   de notificação (`notificar_as`, device tokens) + job `pg_cron`, tabela
   `resgates_cosmicos` + trigger de débito/validação de saldo, RPC
   `enviar_comprovacao` (e ajuste da policy de UPDATE de `coordenadas_voo`),
   bucket `comprovacoes` + policies, e a constraint `unique` em
   `usuarios.email`.
2. Iniciar o projeto Flutter (`flutter create`), já na estrutura
   feature-first decidida (5.4), configurar `supabase_flutter` e Riverpod
   apontando pro projeto Supabase.
3. Portar as telas do protótipo (login, painel do responsável, painel da
   criança, loja) para widgets Flutter, uma a uma.
