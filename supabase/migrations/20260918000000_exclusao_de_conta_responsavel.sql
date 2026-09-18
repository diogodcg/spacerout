-- ============================================================================
-- Exclusão de conta pelo próprio responsável (exigência do Google Play).
--
-- Chamada só pela Edge Function `excluir-conta` (service_role) — nunca
-- direto pelo app — porque depois de apagar as linhas ainda é preciso
-- remover as fotos do Storage e os logins de auth.users, o que só a
-- Admin API faz.
--
-- Duas situações, decididas aqui dentro (mesma transação):
--   * Responsável ÚNICO da família: apaga a organização inteira. O
--     `on delete cascade` de organizacao_id leva usuários, missões,
--     suprimentos, resgates, convites e dispositivos. Devolve os ids de
--     todos os membros pra Edge Function apagar os logins deles.
--   * Existe OUTRO responsável: apaga só este usuário. O que ele criou
--     (missões, suprimentos, convites) passa pro responsável mais antigo,
--     porque criado_por é NOT NULL e sem cascade. validado_por/entregue_por
--     viram NULL em vez de serem reatribuídos — reatribuir falsificaria
--     quem de fato aprovou/entregou.
--
-- Astronauta não usa esta função: os dados do menor são apagados a pedido
-- do responsável (ver docs/exclusao-de-conta.html).
-- ============================================================================
create or replace function public.excluir_conta_responsavel(p_usuario_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_role public.role_tipo;
    v_organizacao_id uuid;
    v_outro_responsavel uuid;
    v_usuarios_ids uuid[];
begin
    select role, organizacao_id into v_role, v_organizacao_id
    from public.usuarios
    where id = p_usuario_id;

    if not found then
        raise exception 'usuario_nao_encontrado' using errcode = 'P0002';
    end if;

    if v_role is distinct from 'responsavel' then
        raise exception 'apenas_responsavel' using errcode = '42501';
    end if;

    -- Trava o candidato pra dois responsáveis apagando a conta ao mesmo
    -- tempo não passarem cada um achando que o outro ainda existe.
    select id into v_outro_responsavel
    from public.usuarios
    where organizacao_id = v_organizacao_id
      and role = 'responsavel'
      and id <> p_usuario_id
    order by created_at
    limit 1
    for update;

    if v_outro_responsavel is null then
        select array_agg(id) into v_usuarios_ids
        from public.usuarios
        where organizacao_id = v_organizacao_id;

        delete from public.organizacoes_familiares
        where id = v_organizacao_id;

        return jsonb_build_object(
            'modo', 'familia',
            'organizacao_id', v_organizacao_id,
            'usuarios_ids', to_jsonb(v_usuarios_ids)
        );
    end if;

    update public.coordenadas_voo
    set criado_por = v_outro_responsavel where criado_por = p_usuario_id;
    update public.suprimentos_cosmicos
    set criado_por = v_outro_responsavel where criado_por = p_usuario_id;
    update public.convites_familiares
    set criado_por = v_outro_responsavel where criado_por = p_usuario_id;

    update public.coordenadas_voo
    set validado_por = null where validado_por = p_usuario_id;
    update public.resgates_suprimentos
    set entregue_por = null where entregue_por = p_usuario_id;

    delete from public.usuarios where id = p_usuario_id;

    return jsonb_build_object(
        'modo', 'individual',
        'organizacao_id', v_organizacao_id,
        'usuarios_ids', jsonb_build_array(p_usuario_id)
    );
end;
$$;

-- Só a Edge Function (service_role) pode chamar: a função recebe o id do
-- usuário como parâmetro e confia nele, então nenhum papel do app pode
-- ter EXECUTE.
revoke all on function public.excluir_conta_responsavel(uuid) from public, anon, authenticated;
grant execute on function public.excluir_conta_responsavel(uuid) to service_role;
