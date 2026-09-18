// Exclusão de conta iniciada pelo próprio responsável, dentro do app
// (exigência do Google Play). Autenticada pelo JWT do usuário logado — o
// id que vai pra RPC vem do token, nunca do corpo da requisição, então
// ninguém consegue apagar a conta de outra pessoa.
//
// Ordem: 1) RPC `excluir_conta_responsavel` apaga as linhas do banco numa
// transação e diz quem foi apagado; 2) remove as fotos do bucket
// `comprovacoes` (só quando a família inteira foi); 3) apaga os logins em
// auth.users. Se 2 ou 3 falharem, o dado pessoal no banco já sumiu — sobra
// só órfão de storage/auth, que dá pra limpar depois; por isso o erro é
// registrado em log e devolvido, mas não desfaz nada.
import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET_COMPROVACOES = "comprovacoes";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
};

function resposta(status: number, corpo: Record<string, unknown>) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return resposta(401, { erro: "nao_autenticado" });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: { user }, error: erroAuth } = await supabase.auth.getUser(token);
  if (erroAuth || !user) return resposta(401, { erro: "nao_autenticado" });

  // Login sem linha em `usuarios` = não terminou o onboarding, não há
  // dado de família pra apagar; só o login.
  const { data: perfil } = await supabase
    .from("usuarios")
    .select("id")
    .eq("id", user.id)
    .maybeSingle();

  let usuariosIds: string[] = [user.id];
  let organizacaoId: string | null = null;
  let modo = "somente_login";

  if (perfil) {
    const { data, error } = await supabase.rpc("excluir_conta_responsavel", {
      p_usuario_id: user.id,
    });

    if (error) {
      if (error.message.includes("apenas_responsavel")) {
        return resposta(403, { erro: "apenas_responsavel" });
      }
      console.error("Falha na RPC excluir_conta_responsavel", { userId: user.id, error });
      return resposta(500, { erro: "falha_ao_excluir_dados" });
    }

    modo = data.modo;
    organizacaoId = data.organizacao_id;
    usuariosIds = data.usuarios_ids;
  }

  const falhas: string[] = [];

  if (modo === "familia" && organizacaoId) {
    // Fotos ficam em `{organizacao_id}/{missao_id}.{ext}`. Lista e apaga em
    // lotes até esvaziar (teto de 50 rodadas contra loop infinito).
    for (let i = 0; i < 50; i++) {
      const { data: arquivos, error } = await supabase.storage
        .from(BUCKET_COMPROVACOES)
        .list(organizacaoId, { limit: 100 });
      if (error) {
        console.error("Falha ao listar fotos", { organizacaoId, error });
        falhas.push("storage");
        break;
      }
      if (!arquivos || arquivos.length === 0) break;

      const { error: erroRemocao } = await supabase.storage
        .from(BUCKET_COMPROVACOES)
        .remove(arquivos.map((a) => `${organizacaoId}/${a.name}`));
      if (erroRemocao) {
        console.error("Falha ao remover fotos", { organizacaoId, erroRemocao });
        falhas.push("storage");
        break;
      }
    }
  }

  for (const id of usuariosIds) {
    const { error } = await supabase.auth.admin.deleteUser(id);
    if (error) {
      console.error("Falha ao apagar login", { id, error });
      falhas.push(`auth:${id}`);
    }
  }

  if (falhas.length > 0) {
    return resposta(500, { erro: "exclusao_parcial", modo, falhas });
  }
  return resposta(200, { ok: true, modo });
});
