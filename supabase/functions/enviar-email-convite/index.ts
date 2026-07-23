// Dispara e-mail de convite via Resend quando um convite é criado ou
// reenviado (trigger notificar_convite_por_email em convites_familiares).
// Autenticado por segredo compartilhado (x-convite-secret), mesmo padrão
// de enviar-lembretes-missao — não pelas chaves anon/service_role.
import { createClient } from "npm:@supabase/supabase-js@2";

const ROLE_LABEL: Record<string, string> = {
  astronauta: "astronauta",
  responsavel: "responsável",
};

Deno.serve(async (req) => {
  const segredoEsperado = Deno.env.get("CONVITE_EMAIL_SECRET");
  if (!segredoEsperado || req.headers.get("x-convite-secret") !== segredoEsperado) {
    return new Response("unauthorized", { status: 401 });
  }

  const { convite_id } = await req.json();
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: convite, error } = await supabase
    .from("convites_familiares")
    .select("email_convidado, role, organizacoes_familiares(nome)")
    .eq("id", convite_id)
    .single();

  if (error || !convite) {
    console.error("Convite não encontrado", { convite_id, error });
    return new Response("convite not found", { status: 404 });
  }

  const nomeFamilia = (convite.organizacoes_familiares as { nome: string }).nome;
  const roleLabel = ROLE_LABEL[convite.role as string] ?? convite.role;

  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "SpaceRout <contato@spacerout.com.br>",
      to: [convite.email_convidado],
      subject: `Você foi convidado pra família "${nomeFamilia}" no SpaceRout!`,
      html: `
        <p>Você foi convidado pra participar da família <strong>${nomeFamilia}</strong>
        no SpaceRout, como <strong>${roleLabel}</strong>.</p>
        <p>Peça pra quem te convidou te passar o aplicativo e entre com
        este mesmo e-mail (Google ou Apple) — você já vai cair direto na
        família certa, sem precisar fazer mais nada.</p>
      `,
    }),
  });

  if (!resp.ok) {
    console.error("Falha ao enviar e-mail via Resend", { status: resp.status, body: await resp.text() });
    return new Response("failed to send email", { status: 502 });
  }

  return new Response("ok", { status: 200 });
});
