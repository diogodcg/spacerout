-- ============================================================================
-- Agendamento do disparo de lembretes/escalonamento de missão (§5.1).
-- A Edge Function (supabase/functions/enviar-lembretes-missao) faz a
-- varredura de fato; esta migration só cria o job pg_cron que a chama a
-- cada minuto via pg_net.
--
-- Autenticação: a Edge Function valida o header x-cron-secret contra a
-- variável de ambiente CRON_SHARED_SECRET (function secret). O valor real
-- do segredo NUNCA é commitado aqui — é lido do Supabase Vault
-- (vault.decrypted_secrets), inserido manualmente uma única vez via SQL
-- Editor (ver README, seção de deploy de push notifications).
-- ============================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'enviar-lembretes-missao',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://kzizdekhohisnixyzlqj.supabase.co/functions/v1/enviar-lembretes-missao',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (
        select decrypted_secret from vault.decrypted_secrets
        where name = 'cron_shared_secret'
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 15000
  ) as request_id;
  $$
);
