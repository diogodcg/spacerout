-- SpaceRout — permite ao responsável excluir uma missão (coordenadas_voo)
--
-- Nenhuma policy de DELETE existia pra coordenadas_voo até aqui (só
-- select/insert/update) — RLS nega por padrão o que não tem policy, então
-- excluir do client falharia silenciosamente. Restrito a status = 'disponivel'
-- (nunca enviada/aprovada/rejeitada): uma missão já aprovada já creditou
-- moedas via trigger aplicar_moedas_aprovadas, e DELETE não dispara lógica
-- de estorno — excluir uma linha dessas quebraria a trilha de auditoria do
-- saldo sem desfazer o crédito. Para remover uma missão em uso, o caminho é
-- desativar (coluna "ativa"), já suportado.
create policy "responsavel_exclui_missoes_disponiveis"
    on public.coordenadas_voo for delete
    using (
        organizacao_id = public.minha_organizacao_id()
        and public.meu_role() = 'responsavel'
        and status = 'disponivel'
    );

-- suprimentos_cosmicos já tem policy "responsavel_gerencia_suprimentos" FOR
-- ALL (inclui DELETE); a FK resgates_suprimentos.suprimento_id é ON DELETE
-- RESTRICT, então o próprio banco recusa excluir um suprimento com histórico
-- de resgate — nenhuma mudança necessária aqui.
