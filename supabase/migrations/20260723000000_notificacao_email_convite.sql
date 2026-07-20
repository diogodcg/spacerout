-- ============================================================================
-- Notificação de convite por e-mail (Resend).
-- Trigger dispara o envio via net.http_post pra Edge Function
-- enviar-email-convite, tanto na criação de um convite quanto no reenvio
-- (ConvitesRepository.reenviarConvite, que só atualiza expira_em). Mesmo
-- padrão de autenticação trigger -> Edge Function do push notifications
-- (segredo compartilhado no Vault, não as chaves anon/service_role).
-- ============================================================================
create or replace function public.notificar_convite_por_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Só dispara em convite novo, ou reenvio explícito (expira_em mudou).
  -- Não dispara quando o UPDATE é o aceite automático
  -- (aceitar_convite_no_login só muda aceito/aceito_em, nunca expira_em).
  if tg_op = 'INSERT' or (tg_op = 'UPDATE' and new.expira_em is distinct from old.expira_em) then
    perform net.http_post(
      url := 'https://kzizdekhohisnixyzlqj.supabase.co/functions/v1/enviar-email-convite',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-convite-secret', (
          select decrypted_secret from vault.decrypted_secrets
          where name = 'convite_email_secret'
        )
      ),
      body := jsonb_build_object('convite_id', new.id),
      timeout_milliseconds := 10000
    );
  end if;
  return new;
end;
$$;

create trigger trg_notificar_convite_por_email
    after insert or update on public.convites_familiares
    for each row execute function public.notificar_convite_por_email();
