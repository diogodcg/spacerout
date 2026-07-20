-- Reverte o grupo compartilhado de missões: testado na prática, editar uma
-- missão atribuída a vários astronautas deve afetar só aquele astronauta,
-- não o grupo inteiro. `missao_grupo_id` só existia pra suportar esse
-- fan-out no UPDATE — sem ele, cada linha volta a ser 100% independente
-- (criada junto, editada separada).
drop index if exists public.idx_coordenadas_grupo;

alter table public.coordenadas_voo
    drop column missao_grupo_id;
