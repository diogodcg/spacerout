// Varre coordenadas_voo em busca de:
//   1) missões "disponivel" cujo notificar_as já passou e ainda não
//      receberam lembrete -> notifica o(s) astronauta(s) atribuído(s)
//      (ou todos da organização, se atribuido_a for null).
//   2) missões que já receberam lembrete, continuam "disponivel" e
//      passaram do prazo de tolerância -> notifica todos os responsaveis
//      da organização (uma única vez).
//
// Chamada a cada minuto pelo pg_cron (ver migration
// 20260722000000_agendamento_lembretes_missao_pg_cron.sql), autenticada por
// um segredo compartilhado próprio (header x-cron-secret) — não pelas
// chaves anon/service_role da Supabase, que exigiriam verify_jwt=true e não
// funcionam com o novo sistema de API keys (sb_publishable_/sb_secret_).
import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const TOLERANCIA_ESCALONAMENTO_MS = 2 * 60 * 60 * 1000; // 2h, ajustável
const FUSO_HORARIO_FAMILIA = "America/Sao_Paulo"; // v1: um único fuso pra
// todas as organizações — não há coluna de timezone por organização no
// schema hoje.

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
  project_id: string;
}

function horaAtualNoFuso(timeZone: string): string {
  const partes = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(new Date());
  const pega = (tipo: string) => partes.find((p) => p.type === tipo)?.value ?? "00";
  return `${pega("hour")}:${pega("minute")}:${pega("second")}`;
}

async function obterAccessTokenFcm(sa: ServiceAccount): Promise<string> {
  const chavePrivada = await importPKCS8(sa.private_key, "RS256");
  const agora = Math.floor(Date.now() / 1000);

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience(sa.token_uri)
    .setIssuedAt(agora)
    .setExpirationTime(agora + 3600)
    .sign(chavePrivada);

  const resp = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!resp.ok) {
    throw new Error(`Falha ao trocar JWT por access token: ${resp.status} ${await resp.text()}`);
  }
  const dados = await resp.json();
  return dados.access_token as string;
}

interface ResultadoEnvio {
  ok: boolean;
  tokenInvalido: boolean;
}

async function enviarFcm(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  titulo: string,
  corpo: string,
  data: Record<string, string>,
): Promise<ResultadoEnvio> {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title: titulo, body: corpo },
          data,
          android: { priority: "high" },
        },
      }),
    },
  );

  if (resp.ok) return { ok: true, tokenInvalido: false };

  const payload = await resp.json().catch(() => null);
  // Formato de erro da FCM HTTP v1 API:
  // { error: { code, message, status, details: [{ "@type": ".../FcmError", errorCode }] } }
  const errorCode = payload?.error?.details?.find((d: Record<string, unknown>) =>
    typeof d["@type"] === "string" && (d["@type"] as string).includes("FcmError")
  )?.errorCode;
  const tokenInvalido = errorCode === "UNREGISTERED" || errorCode === "NOT_FOUND" ||
    errorCode === "INVALID_ARGUMENT";

  console.error("Falha ao enviar FCM", { status: resp.status, errorCode, payload });
  return { ok: false, tokenInvalido };
}

Deno.serve(async (req) => {
  const segredoEsperado = Deno.env.get("CRON_SHARED_SECRET");
  if (!segredoEsperado || req.headers.get("x-cron-secret") !== segredoEsperado) {
    return new Response("unauthorized", { status: 401 });
  }

  const sa: ServiceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!);
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, // client server-to-server, ignora RLS
  );

  const accessToken = await obterAccessTokenFcm(sa);

  const resumo = { lembretes: 0, escalonamentos: 0, tokensRemovidos: 0, erros: 0 };

  // --- 1) LEMBRETE AO ASTRONAUTA ------------------------------------------
  // UPDATE ... RETURNING atômico: "claim" das linhas antes de enviar, para
  // que duas execuções sobrepostas do cron nunca disparem o mesmo lembrete
  // duas vezes (Postgres reavalia o WHERE por linha sob READ COMMITTED).
  const horaAtual = horaAtualNoFuso(FUSO_HORARIO_FAMILIA);
  const { data: missoesLembrete, error: erroLembrete } = await supabase
    .from("coordenadas_voo")
    .update({ lembrete_enviado_em: new Date().toISOString() })
    .eq("ativa", true)
    .eq("status", "disponivel")
    .not("notificar_as", "is", null)
    .is("lembrete_enviado_em", null)
    .lte("notificar_as", horaAtual)
    .select("id, titulo, organizacao_id, atribuido_a");

  if (erroLembrete) {
    console.error("Erro ao buscar/marcar missões para lembrete", erroLembrete);
    resumo.erros++;
  }

  for (const missao of missoesLembrete ?? []) {
    let usuarioIds: string[];
    if (missao.atribuido_a) {
      usuarioIds = [missao.atribuido_a];
    } else {
      // Missão aberta: lembrete vai para todos os astronautas da organização.
      const { data: astronautas } = await supabase
        .from("usuarios")
        .select("id")
        .eq("organizacao_id", missao.organizacao_id)
        .eq("role", "astronauta");
      usuarioIds = (astronautas ?? []).map((u) => u.id);
    }
    if (usuarioIds.length === 0) continue;

    const { data: dispositivos } = await supabase
      .from("dispositivos_notificacao")
      .select("id, fcm_token")
      .in("usuario_id", usuarioIds);

    for (const disp of dispositivos ?? []) {
      const resultado = await enviarFcm(
        accessToken,
        sa.project_id,
        disp.fcm_token,
        "Missão te espera!",
        `Não esqueça: "${missao.titulo}"`,
        { tipo: "lembrete_missao", missao_id: missao.id },
      );
      if (resultado.ok) {
        resumo.lembretes++;
      } else {
        resumo.erros++;
        if (resultado.tokenInvalido) {
          await supabase.from("dispositivos_notificacao").delete().eq("id", disp.id);
          resumo.tokensRemovidos++;
        }
      }
    }
  }

  // --- 2) ESCALONAMENTO AO(S) RESPONSÁVEL(IS) -----------------------------
  const limiteEscalonamento = new Date(Date.now() - TOLERANCIA_ESCALONAMENTO_MS).toISOString();
  const { data: missoesEscalonamento, error: erroEscalonamento } = await supabase
    .from("coordenadas_voo")
    .update({ escalonado_em: new Date().toISOString() })
    .eq("ativa", true)
    .eq("status", "disponivel")
    .not("notificar_as", "is", null)
    .not("lembrete_enviado_em", "is", null)
    .is("escalonado_em", null)
    .lte("lembrete_enviado_em", limiteEscalonamento)
    .select("id, titulo, organizacao_id");

  if (erroEscalonamento) {
    console.error("Erro ao buscar/marcar missões para escalonamento", erroEscalonamento);
    resumo.erros++;
  }

  for (const missao of missoesEscalonamento ?? []) {
    // Múltiplos responsáveis por organização (fluxo de convite) — todos
    // recebem, não só quem criou a missão.
    const { data: responsaveis } = await supabase
      .from("usuarios")
      .select("id")
      .eq("organizacao_id", missao.organizacao_id)
      .eq("role", "responsavel");
    const usuarioIds = (responsaveis ?? []).map((u) => u.id);
    if (usuarioIds.length === 0) continue;

    const { data: dispositivos } = await supabase
      .from("dispositivos_notificacao")
      .select("id, fcm_token")
      .in("usuario_id", usuarioIds);

    for (const disp of dispositivos ?? []) {
      const resultado = await enviarFcm(
        accessToken,
        sa.project_id,
        disp.fcm_token,
        "Missão pendente",
        `"${missao.titulo}" ainda não foi cumprida.`,
        { tipo: "escalonamento_missao", missao_id: missao.id },
      );
      if (resultado.ok) {
        resumo.escalonamentos++;
      } else {
        resumo.erros++;
        if (resultado.tokenInvalido) {
          await supabase.from("dispositivos_notificacao").delete().eq("id", disp.id);
          resumo.tokensRemovidos++;
        }
      }
    }
  }

  console.log("enviar-lembretes-missao concluído", resumo);
  return new Response(JSON.stringify(resumo), {
    headers: { "Content-Type": "application/json" },
  });
});
