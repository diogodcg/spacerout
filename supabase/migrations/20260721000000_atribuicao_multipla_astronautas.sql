-- SpaceRout — atribuição de missão/suprimento a múltiplos astronautas
--
-- Missões: em vez de separar "definição" e "execução por astronauta" em
-- duas tabelas, cada astronauta continua com sua própria linha em
-- `coordenadas_voo` (status/foto/aprovação por linha, sem mudança
-- nenhuma) — só ganham uma coluna `missao_grupo_id` que liga as linhas
-- irmãs criadas juntas na mesma ação de "criar pra vários filhos".
-- Editar título/moedas/recorrência passa a fazer
-- `UPDATE ... WHERE missao_grupo_id = X`, atualizando o grupo inteiro.
alter table public.coordenadas_voo
    add column missao_grupo_id uuid;

create index idx_coordenadas_grupo on public.coordenadas_voo (missao_grupo_id);

-- Suprimentos: não têm ciclo de conclusão próprio (o resgate já é uma
-- tabela separada), então a coluna única `atribuido_a` vira uma tabela de
-- junção — permite reservar o mesmo suprimento pra mais de um astronauta.
create table public.suprimentos_atribuicoes (
    id uuid primary key default gen_random_uuid(),
    organizacao_id uuid not null references public.organizacoes_familiares (id) on delete cascade,
    suprimento_id uuid not null references public.suprimentos_cosmicos (id) on delete cascade,
    astronauta_id uuid not null references public.usuarios (id),
    created_at timestamptz not null default now(),
    unique (suprimento_id, astronauta_id)
);

create index idx_suprimentos_atrib_suprimento on public.suprimentos_atribuicoes (suprimento_id);

alter table public.suprimentos_atribuicoes enable row level security;

create policy "suprimentos_atrib_select_mesma_org"
    on public.suprimentos_atribuicoes for select
    using (organizacao_id = public.minha_organizacao_id());

create policy "responsavel_gerencia_suprimentos_atrib"
    on public.suprimentos_atribuicoes for all
    using (organizacao_id = public.minha_organizacao_id() and public.meu_role() = 'responsavel')
    with check (organizacao_id = public.minha_organizacao_id() and public.meu_role() = 'responsavel');

-- Backfill dos dados existentes antes de derrubar a coluna antiga.
insert into public.suprimentos_atribuicoes (organizacao_id, suprimento_id, astronauta_id)
select organizacao_id, id, atribuido_a
from public.suprimentos_cosmicos
where atribuido_a is not null;

alter table public.suprimentos_cosmicos drop column atribuido_a;

-- Nulo = ninguém reservou o suprimento = disponível pra qualquer
-- astronauta da organização (mesma semântica de antes, só que agora
-- checada via ausência de linhas em vez de coluna nula).
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

    if exists (select 1 from public.suprimentos_atribuicoes where suprimento_id = new.suprimento_id)
       and not exists (
           select 1 from public.suprimentos_atribuicoes
           where suprimento_id = new.suprimento_id and astronauta_id = new.resgatado_por
       ) then
        raise exception 'Este suprimento foi reservado para outro(s) astronauta(s).';
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

-- Relatório por astronauta — usada pela tela "Relatório" no painel do
-- responsável no lugar do seletor de criança revertido no Drawer.
create or replace function public.relatorio_astronautas()
returns table (
    astronauta_id uuid,
    nome_exibicao text,
    saldo_moedas integer,
    missoes_concluidas bigint,
    missoes_em_aberto bigint,
    premios_conquistados bigint
)
language sql
stable
security definer
set search_path = public
as $$
    select
        u.id,
        u.nome_exibicao,
        u.saldo_moedas,
        (select count(*) from public.coordenadas_voo cv where cv.atribuido_a = u.id and cv.status = 'aprovada'),
        (select count(*) from public.coordenadas_voo cv where cv.atribuido_a = u.id and cv.status <> 'aprovada'),
        (select count(*) from public.resgates_suprimentos r where r.resgatado_por = u.id and r.status = 'entregue')
    from public.usuarios u
    where u.organizacao_id = public.minha_organizacao_id()
      and u.role = 'astronauta'
    order by u.nome_exibicao;
$$;
