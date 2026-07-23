-- ============================================================
-- Alinha o nome do enum de role ao padrão dos demais enums do
-- schema (português + sufixo `_tipo`/`_status`: `plano_tipo`,
-- `recorrencia_tipo`, `missao_status`, `resgate_status`).
-- `user_role` era o único em inglês, resquício do scaffold inicial.
-- Rename de tipo é só metadata (não reescreve dados/colunas).
-- ============================================================

alter type public.user_role rename to role_tipo;
