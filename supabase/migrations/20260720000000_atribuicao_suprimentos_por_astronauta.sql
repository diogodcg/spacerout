-- SpaceRout — suprimentos atribuíveis a um astronauta específico
--
-- Espelha `coordenadas_voo.atribuido_a`: um responsável pode combinar uma
-- recompensa específica pra um filho (ex.: "bicicleta nova" só pra um deles)
-- em vez de deixar toda recompensa disponível pra qualquer astronauta da
-- família. Nulo continua significando "aberto pra qualquer um", igual hoje.
alter table public.suprimentos_cosmicos
    add column atribuido_a uuid references public.usuarios (id);

comment on column public.suprimentos_cosmicos.atribuido_a is
    'Nulo = disponível pra qualquer astronauta da organização. Setado = só '
    'esse astronauta pode resgatar (checado em processar_resgate_suprimento).';

-- Sem essa checagem, RLS/trigger atuais deixariam um astronauta resgatar um
-- suprimento atribuído ao irmão — a policy de insert só valida organização
-- e role, não atribuição.
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
    v_atribuido_a uuid;
    v_linhas_afetadas integer;
begin
    select organizacao_id, custo_moedas, ativo, atribuido_a
        into v_organizacao_suprimento, v_custo, v_ativo, v_atribuido_a
    from public.suprimentos_cosmicos
    where id = new.suprimento_id;

    if v_organizacao_suprimento is distinct from new.organizacao_id then
        raise exception 'Suprimento não pertence à organização informada.';
    end if;

    if not v_ativo then
        raise exception 'Suprimento indisponível para resgate.';
    end if;

    if v_atribuido_a is not null and v_atribuido_a is distinct from new.resgatado_por then
        raise exception 'Este suprimento foi reservado para outro astronauta.';
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
