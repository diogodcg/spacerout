-- SpaceRout Core — schema inicial (Supabase / PostgreSQL)
--
-- Baseado estritamente na lógica de negócio do protótipo Streamlit:
--   - common.py           (STATUS_*, roles)
--   - home.py             (autenticação, roles "responsavel" / "filho")
--   - pages/1_Painel_do_Responsável.py  (cadastro de tarefas/prêmios, validação)
--   - pages/2_Painel_da_Criança.py      (missões, saldo de moedas, loja, resgate)
--   - pages/3_Painel_do_Administrador.py (cadastro de usuários por role)
--
-- Decisões de design registradas nos comentários abaixo, para não se perderem
-- na tradução do protótipo (planilha Google Sheets) para um schema relacional.

-- ============================================================================
-- EXTENSÕES
-- ============================================================================
create extension if not exists pgcrypto; -- gen_random_uuid()

-- ============================================================================
-- TIPOS ENUMERADOS
-- ============================================================================
create type public.user_role as enum ('responsavel', 'astronauta');
create type public.plano_tipo as enum ('gratuito', 'anual');
create type public.recorrencia_tipo as enum ('diaria', 'semanal', 'pontual');
create type public.missao_status as enum ('disponivel', 'enviada', 'aprovada', 'rejeitada');

-- ============================================================================
-- TABELA: organizacoes_familiares
-- Controle do plano (equivalente a uma "família" / tenant no app novo).
-- Não existe hoje no protótipo (que atende só uma família via planilha única);
-- é a base da futura multi-tenancy.
-- ============================================================================
create table public.organizacoes_familiares (
    id uuid primary key default gen_random_uuid(),
    nome text not null,
    plano public.plano_tipo not null default 'gratuito',
    plano_expira_em date, -- null enquanto 'gratuito'; setado quando vira 'anual'
    ativo boolean not null default true,
    created_at timestamptz not null default now()
);

comment on table public.organizacoes_familiares is
    'Uma organização = uma família assinante. Trocas de plano (ex.: pagamento '
    'confirmado) devem ser feitas via service role, fora do RLS de usuário comum.';

-- ============================================================================
-- TABELA: usuarios
-- Substitui a aba "usuarios" da planilha. A senha deixa de existir aqui:
-- autenticação passa a ser feita pelo Supabase Auth (auth.users). O "id"
-- desta tabela É o auth.users.id (1:1), então não há coluna de senha.
-- ============================================================================
create table public.usuarios (
    id uuid primary key references auth.users (id) on delete cascade,
    organizacao_id uuid not null references public.organizacoes_familiares (id) on delete cascade,
    role public.user_role not null,
    nome_exibicao text not null,
    email text,
    -- Saldo corrente de moedas do astronauta (irrelevante para "responsavel").
    -- Mantido por trigger (ver aplicar_moedas_aprovadas) toda vez que uma
    -- coordenada_voo muda para 'aprovada' — evita recalcular o histórico
    -- inteiro a cada carregamento de tela, como o protótipo faz hoje.
    saldo_moedas integer not null default 0,
    -- Super admin do protótipo (credencial em st.secrets, fora da planilha).
    -- Aqui vira uma flag de administrador de plataforma, não vinculada a
    -- nenhuma organização específica.
    is_platform_admin boolean not null default false,
    created_at timestamptz not null default now()
);

comment on table public.usuarios is
    'Perfil de aplicação vinculado 1:1 a auth.users. role = responsavel '
    '(cria missões, aprova comprovações) ou astronauta (executa missões, '
    'resgata prêmios) — equivalentes a "responsavel" e "filho" no protótipo.';

create index idx_usuarios_organizacao on public.usuarios (organizacao_id);

-- ============================================================================
-- TABELA: coordenadas_voo
-- Painel de missões. Cada linha é UM CICLO de missão (mirando exatamente o
-- que "tarefas_historico" já faz hoje: uma linha por envio), com moedas,
-- recorrência e status. Uma nova linha é criada a cada ciclo (diário/semanal/
-- pontual) em vez de sobrescrever a anterior — é o que preserva o histórico
-- de ganhos e permite recalcular ou auditar o saldo a qualquer momento.
-- ============================================================================
create table public.coordenadas_voo (
    id uuid primary key default gen_random_uuid(),
    organizacao_id uuid not null references public.organizacoes_familiares (id) on delete cascade,
    titulo text not null,
    moedas integer not null check (moedas > 0),
    recorrencia public.recorrencia_tipo not null,
    -- Controla se esta missão ainda está disponível para novos ciclos
    -- (equivalente à coluna "ativa" de tarefas_cadastro). Também é o campo
    -- usado pela trava freemium abaixo.
    ativa boolean not null default true,
    criado_por uuid not null references public.usuarios (id),
    -- NULL = missão aberta para qualquer astronauta da organização
    -- (comportamento atual: tarefas não são atribuídas a uma criança específica).
    atribuido_a uuid references public.usuarios (id),
    -- Preenchido quando um astronauta efetivamente envia a comprovação.
    enviado_por uuid references public.usuarios (id),
    status public.missao_status not null default 'disponivel',
    foto_url text,
    data_envio timestamptz,
    validado_por uuid references public.usuarios (id),
    data_validacao timestamptz,
    created_at timestamptz not null default now()
);

comment on table public.coordenadas_voo is
    'Uma linha = um ciclo de missão (nunca é reescrita após aprovada/rejeitada, '
    'só linhas novas são criadas para o próximo ciclo). status espelha as '
    'constantes STATUS_PENDENTE/APROVADA/REJEITADA do protótipo, com '
    '"disponivel" cobrindo o estado anterior ao primeiro envio.';

create index idx_coordenadas_organizacao on public.coordenadas_voo (organizacao_id);
create index idx_coordenadas_status on public.coordenadas_voo (organizacao_id, status);
create index idx_coordenadas_atribuido on public.coordenadas_voo (atribuido_a);

-- ============================================================================
-- TABELA: suprimentos_cosmicos
-- Substitui "premios_cadastro": itens da loja e custo em moedas.
-- (O fluxo de resgate/entrega — "premios_historico" — fica fora deste
-- primeiro passo; ver observação final.)
-- ============================================================================
create table public.suprimentos_cosmicos (
    id uuid primary key default gen_random_uuid(),
    organizacao_id uuid not null references public.organizacoes_familiares (id) on delete cascade,
    nome text not null,
    custo_moedas integer not null check (custo_moedas > 0),
    ativo boolean not null default true,
    criado_por uuid not null references public.usuarios (id),
    created_at timestamptz not null default now()
);

create index idx_suprimentos_organizacao on public.suprimentos_cosmicos (organizacao_id);

-- ============================================================================
-- TRAVA FREEMIUM: máx. 5 itens ativos (missões OU prêmios) por organização
-- no plano 'gratuito'. Espelha o requisito de negócio, não algo que já
-- existia no protótipo (que não tinha limite nenhum).
-- ============================================================================
create or replace function public.verificar_limite_freemium()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_plano public.plano_tipo;
    v_limite constant integer := 5;
    v_ativos integer;
begin
    select plano into v_plano
    from public.organizacoes_familiares
    where id = new.organizacao_id;

    if v_plano is distinct from 'gratuito' then
        return new;
    end if;

    if tg_table_name = 'coordenadas_voo' then
        if new.ativa is not true then
            return new;
        end if;
        if tg_op = 'UPDATE' and old.ativa is true then
            return new; -- já estava ativa, não é uma nova ativação
        end if;
        select count(*) into v_ativos
        from public.coordenadas_voo
        where organizacao_id = new.organizacao_id and ativa is true;

    elsif tg_table_name = 'suprimentos_cosmicos' then
        if new.ativo is not true then
            return new;
        end if;
        if tg_op = 'UPDATE' and old.ativo is true then
            return new;
        end if;
        select count(*) into v_ativos
        from public.suprimentos_cosmicos
        where organizacao_id = new.organizacao_id and ativo is true;
    end if;

    if v_ativos >= v_limite then
        raise exception
            'Plano gratuito permite no máximo % itens ativos em %',
            v_limite, tg_table_name
            using errcode = 'check_violation';
    end if;

    return new;
end;
$$;

create trigger trg_limite_freemium_coordenadas
    before insert or update on public.coordenadas_voo
    for each row execute function public.verificar_limite_freemium();

create trigger trg_limite_freemium_suprimentos
    before insert or update on public.suprimentos_cosmicos
    for each row execute function public.verificar_limite_freemium();

-- ============================================================================
-- SALDO DE MOEDAS: incrementa usuarios.saldo_moedas quando uma coordenada_voo
-- passa a 'aprovada'. Só dispara na transição (evita duplicar em updates
-- irrelevantes, ex.: edição de foto_url).
-- ============================================================================
create or replace function public.aplicar_moedas_aprovadas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.status = 'aprovada'
       and (tg_op = 'INSERT' or old.status is distinct from 'aprovada') then
        update public.usuarios
        set saldo_moedas = saldo_moedas + new.moedas
        where id = coalesce(new.enviado_por, new.atribuido_a);
    end if;
    return new;
end;
$$;

create trigger trg_aplicar_moedas_aprovadas
    after insert or update on public.coordenadas_voo
    for each row execute function public.aplicar_moedas_aprovadas();

-- ============================================================================
-- HELPERS PARA RLS
-- SECURITY DEFINER + search_path fixo para evitar recursão de RLS e
-- sequestro de search_path.
-- ============================================================================
create or replace function public.minha_organizacao_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select organizacao_id from public.usuarios where id = auth.uid();
$$;

create or replace function public.meu_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
    select role from public.usuarios where id = auth.uid();
$$;

create or replace function public.sou_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(is_platform_admin, false) from public.usuarios where id = auth.uid();
$$;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
alter table public.organizacoes_familiares enable row level security;
alter table public.usuarios enable row level security;
alter table public.coordenadas_voo enable row level security;
alter table public.suprimentos_cosmicos enable row level security;

-- organizacoes_familiares: leitura da própria organização; escrita (ex.:
-- mudança de plano após pagamento confirmado) fica de fora do RLS de
-- usuário comum e deve ser feita via service role.
create policy "org_select_membros"
    on public.organizacoes_familiares for select
    using (id = public.minha_organizacao_id() or public.sou_platform_admin());

-- usuarios
create policy "usuarios_select_mesma_org"
    on public.usuarios for select
    using (organizacao_id = public.minha_organizacao_id() or public.sou_platform_admin());

create policy "usuarios_update_proprio_perfil"
    on public.usuarios for update
    using (id = auth.uid())
    with check (
        id = auth.uid()
        and organizacao_id = public.minha_organizacao_id()
        and role = public.meu_role()
    );

create policy "responsavel_insere_usuarios_da_org"
    on public.usuarios for insert
    with check (
        public.meu_role() = 'responsavel'
        and organizacao_id = public.minha_organizacao_id()
    );

create policy "responsavel_remove_astronautas_da_org"
    on public.usuarios for delete
    using (
        public.meu_role() = 'responsavel'
        and organizacao_id = public.minha_organizacao_id()
        and role = 'astronauta'
    );

-- coordenadas_voo
create policy "coordenadas_select_mesma_org"
    on public.coordenadas_voo for select
    using (organizacao_id = public.minha_organizacao_id());

create policy "responsavel_cria_coordenadas"
    on public.coordenadas_voo for insert
    with check (
        public.meu_role() = 'responsavel'
        and organizacao_id = public.minha_organizacao_id()
        and criado_por = auth.uid()
    );

-- NOTA: RLS controla LINHAS, não COLUNAS. Esta policy permite que um
-- astronauta atualize uma coordenada_voo atribuída a ele (para enviar
-- comprovação), mas não impede — a nível de banco — que ele altere "moedas"
-- em vez de só "status"/"foto_url". Restringir colunas exige checagem na
-- API/app (ou uma função RPC dedicada em vez de UPDATE direto). Sinalizando
-- porque é o tipo de lacuna que vira bug de segurança se for esquecida.
create policy "atualizacao_coordenadas_mesma_org"
    on public.coordenadas_voo for update
    using (organizacao_id = public.minha_organizacao_id())
    with check (
        organizacao_id = public.minha_organizacao_id()
        and (
            public.meu_role() = 'responsavel'
            or (
                public.meu_role() = 'astronauta'
                and (atribuido_a = auth.uid() or atribuido_a is null)
            )
        )
    );

-- suprimentos_cosmicos
create policy "suprimentos_select_mesma_org"
    on public.suprimentos_cosmicos for select
    using (organizacao_id = public.minha_organizacao_id());

create policy "responsavel_gerencia_suprimentos"
    on public.suprimentos_cosmicos for all
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    )
    with check (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    );
