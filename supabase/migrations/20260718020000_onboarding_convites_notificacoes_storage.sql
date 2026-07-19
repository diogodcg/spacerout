-- SpaceRout — onboarding de organização nova, convites completos, campos de
-- notificação, device tokens e bucket de comprovação de missão.
--
-- Fecha as lacunas do PLANO_MIGRACAO.md:
--   §5.2 fluxo de convite (role/criado_por/expira_em em convites_familiares,
--        trigger de aceite em auth.users, bloqueio de e-mail duplicado)
--   §5.3 onboarding de organização nova (RPC criar_organizacao)
--   §5.5.2 correção: astronauta não pode mais dar UPDATE direto em
--        coordenadas_voo (só via RPC enviar_comprovacao_missao, já existente)
--   §5.5.3 bucket de Storage `comprovacoes` (privado, isolado por organização)
--   §4.5 / §5.2 constraint unique em usuarios.email
--   §5.1 apenas os CAMPOS de notificação e a tabela de device tokens —
--        o job pg_cron + Edge Function de disparo fica FORA desta migration
--        (precisa de deploy de código e credenciais FCM, não é só SQL).

-- ============================================================================
-- usuarios.email único (necessário para detectar convite de e-mail já
-- vinculado a outra organização, ver trigger abaixo)
-- ============================================================================
alter table public.usuarios
    add constraint usuarios_email_unique unique (email);

-- ============================================================================
-- CONVITES: completa convites_familiares com os campos decididos em §5.2
-- que a migration anterior deixou de fora (role, criado_por, expira_em).
-- Tabela ainda não tem uso em produção, então as colunas entram NOT NULL
-- sem precisar de backfill.
-- ============================================================================
alter table public.convites_familiares
    add column role public.user_role not null,
    add column criado_por uuid not null references public.usuarios (id),
    add column expira_em timestamptz not null default (now() + interval '7 days'),
    add column aceito_em timestamptz;

comment on column public.convites_familiares.expira_em is
    'Convite não aceito até este momento é considerado expirado (checado em '
    'query, não em coluna de status separada). Responsável reenvia atualizando '
    'esta mesma linha via a policy de UPDATE abaixo.';

-- Bloqueia e-mail já vinculado a usuário de OUTRA organização no momento da
-- criação do convite (§5.2, "bloqueado na criação, não na aceitação").
create or replace function public.verificar_email_convite_disponivel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if exists (
        select 1 from public.usuarios
        where email = new.email_convidado
          and organizacao_id <> new.organizacao_id
    ) then
        raise exception 'Este e-mail já pertence a outra família.'
            using errcode = 'unique_violation';
    end if;
    return new;
end;
$$;

create trigger trg_verificar_email_convite
    before insert on public.convites_familiares
    for each row execute function public.verificar_email_convite_disponivel();

-- criado_por precisa ser o próprio chamador (a policy antiga não checava isso).
drop policy "responsavel_cria_convites" on public.convites_familiares;

create policy "responsavel_cria_convites"
    on public.convites_familiares for insert
    with check (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
        and criado_por = auth.uid()
    );

-- Reenvio de convite expirado: responsável pode atualizar (não deletar +
-- recriar) uma linha ainda não aceita da própria organização — útil pro app
-- fazer upsert em vez de gerenciar delete+insert.
create policy "responsavel_reenvia_convite"
    on public.convites_familiares for update
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
        and aceito = false
    )
    with check (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    );

-- ============================================================================
-- ACEITE DE CONVITE NO PRIMEIRO LOGIN (§5.2)
-- Trigger em auth.users: se existir convite pendente e não expirado pro
-- e-mail que acabou de logar, cria a linha em usuarios já vinculada à
-- organização/role do convite. Se não existir, não faz nada — o app detecta
-- "logado sem linha em usuarios" e manda pro onboarding (criar_organizacao).
-- ============================================================================
create or replace function public.aceitar_convite_no_login()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_convite record;
begin
    select * into v_convite
    from public.convites_familiares
    where email_convidado = new.email
      and aceito = false
      and expira_em > now()
    order by created_at desc
    limit 1;

    if v_convite.id is not null then
        insert into public.usuarios (id, organizacao_id, role, nome_exibicao, email)
        values (
            new.id,
            v_convite.organizacao_id,
            v_convite.role,
            coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', new.email),
            new.email
        )
        on conflict (id) do nothing;

        update public.convites_familiares
        set aceito = true, aceito_em = now()
        where id = v_convite.id;
    end if;

    return new;
end;
$$;

create trigger trg_aceitar_convite_no_login
    after insert on auth.users
    for each row execute function public.aceitar_convite_no_login();

-- ============================================================================
-- ONBOARDING DE ORGANIZAÇÃO NOVA (§5.3)
-- Chamado explicitamente pelo app quando auth.uid() loga sem linha em
-- usuarios e sem convite pendente (trigger acima não achou nada). Cria a
-- organização e o usuário responsável na mesma transação.
-- ============================================================================
create or replace function public.criar_organizacao(p_nome text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_org_id uuid;
begin
    if exists (select 1 from public.usuarios where id = auth.uid()) then
        raise exception 'Usuário já pertence a uma organização.';
    end if;

    insert into public.organizacoes_familiares (nome)
    values (p_nome)
    returning id into v_org_id;

    insert into public.usuarios (id, organizacao_id, role, nome_exibicao, email)
    select auth.uid(), v_org_id, 'responsavel',
           coalesce(raw_user_meta_data ->> 'name', raw_user_meta_data ->> 'full_name', email),
           email
    from auth.users
    where id = auth.uid();

    return v_org_id;
end;
$$;

-- ============================================================================
-- CORREÇÃO §5.5.2: astronauta deixa de conseguir UPDATE direto em
-- coordenadas_voo (a lacuna 4.2 registrada na migration inicial). Envio de
-- comprovação passa a ser exclusivamente via enviar_comprovacao_missao
-- (já existente, migration anterior), que roda como security definer e
-- ignora esta policy.
-- ============================================================================
drop policy "atualizacao_coordenadas_mesma_org" on public.coordenadas_voo;

create policy "responsavel_atualiza_coordenadas"
    on public.coordenadas_voo for update
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    )
    with check (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
    );

-- ============================================================================
-- NOTIFICAÇÃO DE MISSÃO PENDENTE (§5.1) — apenas os campos/tabela de schema.
-- O job pg_cron + Edge Function que efetivamente dispara via FCM fica para
-- uma tarefa separada de infraestrutura (deploy de Edge Function + service
-- account do Firebase), não cabe numa migration SQL.
-- ============================================================================
alter table public.coordenadas_voo
    add column notificar_as time,
    add column lembrete_enviado_em timestamptz,
    add column escalonado_em timestamptz;

comment on column public.coordenadas_voo.notificar_as is
    'Horário do dia (definido pelo responsável) em que o astronauta recebe '
    'o lembrete push desta missão, se ainda "disponivel" nesse horário.';
comment on column public.coordenadas_voo.escalonado_em is
    'Setado quando a segunda notificação (aviso ao responsável de missão '
    'não cumprida) é disparada, para não duplicar o escalonamento.';

create table public.dispositivos_notificacao (
    id uuid primary key default gen_random_uuid(),
    usuario_id uuid not null references public.usuarios (id) on delete cascade,
    fcm_token text not null unique,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

comment on table public.dispositivos_notificacao is
    'Um usuário pode ter mais de um dispositivo/token FCM registrado. A '
    'Edge Function de disparo (fora desta migration) lê esta tabela via '
    'service_role, então não precisa de policy de leitura para outros roles.';

create index idx_dispositivos_usuario on public.dispositivos_notificacao (usuario_id);

alter table public.dispositivos_notificacao enable row level security;

create policy "usuario_gerencia_proprios_dispositivos"
    on public.dispositivos_notificacao for all
    using (usuario_id = auth.uid())
    with check (usuario_id = auth.uid());

-- ============================================================================
-- STORAGE: bucket privado para fotos de comprovação de missão (§5.5.3)
-- Caminho esperado: {organizacao_id}/{missao_id}.{ext}. Isolamento por
-- organização feito aqui; a autorização fina (se a missão é do astronauta
-- que está enviando) já é responsabilidade de enviar_comprovacao_missao.
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('comprovacoes', 'comprovacoes', false)
on conflict (id) do nothing;

create policy "comprovacoes_select_mesma_org"
    on storage.objects for select
    using (
        bucket_id = 'comprovacoes'
        and (storage.foldername(name))[1] = public.minha_organizacao_id()::text
    );

create policy "comprovacoes_insert_mesma_org"
    on storage.objects for insert
    with check (
        bucket_id = 'comprovacoes'
        and (storage.foldername(name))[1] = public.minha_organizacao_id()::text
    );
