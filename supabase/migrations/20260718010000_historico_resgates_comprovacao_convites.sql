-- SpaceRout — histórico de resgates, RPC de comprovação e convites familiares
--
-- Fecha as lacunas 4.2 e 6.1 registradas no PLANO_MIGRACAO.md, a partir de
-- um rascunho externo (Gemini) corrigido nos seguintes pontos:
--   - nomes de coluna alinhados à convenção do schema inicial
--     (organizacao_id / *_por, em vez de id_organizacao / id_*)
--   - enviar_comprovacao_missao referenciava colunas inexistentes
--     (id_organizacao, url_foto_comprovacao) e não setava enviado_por,
--     o que faria aplicar_moedas_aprovadas não creditar ninguém
--   - enviar_comprovacao_missao não respeitava atribuido_a (permitia
--     qualquer astronauta enviar comprovação de missão do irmão)
--   - débito de moedas no resgate tinha race condition (SELECT + UPDATE
--     separados permitia saldo negativo em resgates concorrentes)
--   - funções SECURITY DEFINER sem SET search_path = public
--   - convites_familiares criada sem RLS habilitado

-- ============================================================================
-- HISTÓRICO DE RESGATES (substitui "premios_historico" do protótipo)
-- ============================================================================
create type public.resgate_status as enum ('solicitado', 'entregue');

create table public.resgates_suprimentos (
    id uuid primary key default gen_random_uuid(),
    organizacao_id uuid not null references public.organizacoes_familiares (id) on delete cascade,
    -- Sem "on delete cascade": mesma lógica de criado_por/enviado_por/validado_por
    -- em coordenadas_voo — preserva o histórico de resgate mesmo que o usuário
    -- seja removido depois.
    resgatado_por uuid not null references public.usuarios (id),
    suprimento_id uuid not null references public.suprimentos_cosmicos (id) on delete restrict,
    -- Travado pelo trigger abaixo com o custo real do item no momento do
    -- resgate (o preço pode mudar depois; o histórico não deve mudar junto).
    moedas_gastas integer not null check (moedas_gastas > 0),
    status public.resgate_status not null default 'solicitado',
    entregue_por uuid references public.usuarios (id),
    data_entrega timestamptz,
    created_at timestamptz not null default now()
);

comment on table public.resgates_suprimentos is
    'Uma linha = um resgate de prêmio. moedas_gastas é travado pelo trigger '
    'processar_resgate_suprimento com o custo do item no momento do resgate, '
    'não o custo atual em suprimentos_cosmicos.';

create index idx_resgates_organizacao on public.resgates_suprimentos (organizacao_id);
create index idx_resgates_resgatado_por on public.resgates_suprimentos (resgatado_por);

alter table public.resgates_suprimentos enable row level security;

create policy "resgates_select_mesma_org"
    on public.resgates_suprimentos for select
    using (organizacao_id = public.minha_organizacao_id());

create policy "astronauta_cria_resgate"
    on public.resgates_suprimentos for insert
    with check (
        organizacao_id = public.minha_organizacao_id()
        and resgatado_por = auth.uid()
        and public.meu_role() = 'astronauta'
    );

-- Único caminho de update: responsável confirma entrega. entregue_por é
-- exigido junto com a mudança de status para não permitir que um
-- responsável registre a entrega em nome de outro.
create policy "responsavel_confirma_entrega"
    on public.resgates_suprimentos for update
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    )
    with check (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
        and status = 'entregue'
        and entregue_por = auth.uid()
    );

-- Defesa extra contra saldo negativo (além da checagem atômica no trigger
-- abaixo): nenhuma linha de usuarios deve existir com saldo < 0.
alter table public.usuarios
    add constraint usuarios_saldo_moedas_nao_negativo check (saldo_moedas >= 0);

-- Debita o saldo e trava o custo histórico. A checagem de saldo e o débito
-- acontecem na MESMA instrução UPDATE (saldo_moedas >= v_custo na cláusula
-- WHERE) para serem atômicos: sob concorrência, a segunda transação só
-- executa o UPDATE depois que a primeira commita, e reavalia a condição
-- contra o saldo já atualizado — evita a corrida do "SELECT saldo, depois
-- decide, depois UPDATE" (que permitiria dois resgates simultâneos
-- passarem na checagem com o mesmo saldo e derrubar o total abaixo de zero).
create or replace function public.processar_resgate_suprimento()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_custo integer;
    v_organizacao_suprimento uuid;
    v_ativo boolean;
    v_linhas_afetadas integer;
begin
    select organizacao_id, custo_moedas, ativo
        into v_organizacao_suprimento, v_custo, v_ativo
    from public.suprimentos_cosmicos
    where id = new.suprimento_id;

    if v_organizacao_suprimento is distinct from new.organizacao_id then
        raise exception 'Suprimento não pertence à organização informada.';
    end if;

    if not v_ativo then
        raise exception 'Suprimento indisponível para resgate.';
    end if;

    new.moedas_gastas := v_custo;

    update public.usuarios
    set saldo_moedas = saldo_moedas - v_custo
    where id = new.resgatado_por
      and saldo_moedas >= v_custo;

    get diagnostics v_linhas_afetadas = row_count;

    if v_linhas_afetadas = 0 then
        raise exception 'Saldo de moedas insuficiente para este resgate galáctico.'
            using errcode = 'check_violation';
    end if;

    return new;
end;
$$;

create trigger trg_processar_resgate_suprimento
    before insert on public.resgates_suprimentos
    for each row execute function public.processar_resgate_suprimento();

-- ============================================================================
-- RPC: ENVIO DE COMPROVAÇÃO DE MISSÃO
-- Fecha a lacuna de RLS controlar linha e não coluna (ver comentário em
-- coordenadas_voo, migration inicial): em vez de um UPDATE direto do
-- client, a comprovação passa por esta função, que só altera status,
-- foto_url, enviado_por e data_envio — nunca "moedas".
-- ============================================================================
create or replace function public.enviar_comprovacao_missao(p_missao_id uuid, p_foto_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.meu_role() <> 'astronauta' or not exists (
        select 1 from public.coordenadas_voo
        where id = p_missao_id
          and organizacao_id = public.minha_organizacao_id()
          and status = 'disponivel'
          -- Missão aberta (sem atribuição) ou atribuída a quem está enviando;
          -- sem essa checagem, qualquer astronauta da organização poderia
          -- enviar comprovação de uma missão do irmão/irmã.
          and (atribuido_a = auth.uid() or atribuido_a is null)
    ) then
        raise exception 'Operação não autorizada ou missão indisponível para envio.';
    end if;

    update public.coordenadas_voo
    set status = 'enviada',
        foto_url = p_foto_url,
        enviado_por = auth.uid(),
        data_envio = now()
    where id = p_missao_id;
end;
$$;

-- ============================================================================
-- CONVITES FAMILIARES
-- Responsável cadastra o e-mail de um membro da família; ao logar pela
-- primeira vez com esse e-mail (Google/Apple), o novo usuário é vinculado
-- a esta organizacao_id em vez de criar uma organização nova.
--
-- NOTA: esta migration só cria a tabela e as policies de gestão do
-- convite pelo responsável. A lógica que efetivamente consome um convite
-- no primeiro login (handler em auth.users, matching por e-mail) ainda
-- é um item em aberto no PLANO_MIGRACAO.md (seção 6) — depende de decidir
-- o fluxo de onboarding de uma organização nova.
-- ============================================================================
create table public.convites_familiares (
    id uuid primary key default gen_random_uuid(),
    organizacao_id uuid not null references public.organizacoes_familiares (id) on delete cascade,
    email_convidado text not null,
    aceito boolean not null default false,
    created_at timestamptz not null default now(),
    unique (organizacao_id, email_convidado)
);

create index idx_convites_organizacao on public.convites_familiares (organizacao_id);
create index idx_convites_email_pendente on public.convites_familiares (email_convidado) where not aceito;

alter table public.convites_familiares enable row level security;

create policy "responsavel_ve_convites_da_org"
    on public.convites_familiares for select
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    );

create policy "responsavel_cria_convites"
    on public.convites_familiares for insert
    with check (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    );

create policy "responsavel_remove_convites_da_org"
    on public.convites_familiares for delete
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    );
