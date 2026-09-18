/// Chaves e IDs de produto do RevenueCat — públicos por natureza (igual a
/// `SupabaseConfig.publishableKey`), seguros para embutir no cliente.
///
/// [revenueCatApiKey] é a Public API Key do app "SpaceRout (Play Store)" no
/// RevenueCat (Apps → SpaceRout (Play Store) → Public API Key, prefixo
/// `goog_`). NÃO usar a chave de "Test configuration" (`test_…`) em build de
/// release: o SDK mostra "Wrong API Key" e fecha o app de propósito.
///
/// [produtoTier1]/[produtoTier2] precisam bater exatamente com os IDs
/// esperados pelo webhook (`supabase/functions/webhook-revenuecat/index.ts`)
/// e com os produtos cadastrados no Google Play Console.
class AssinaturaConfig {
  static const revenueCatApiKey = 'goog_ytQMjJZQoyqivpDcnahUphSuPrR';
  static const produtoTier1 = 'spacerout_familia_anual';
  static const produtoTier2 = 'spacerout_familia_grande_anual';

  /// Teto de usuários por produto — precisa bater com `PLANO_MAX_USUARIOS`
  /// em `supabase/functions/webhook-revenuecat/index.ts`. Usado só pra
  /// recomendar automaticamente o tier certo na tela de assinatura; quem
  /// decide de verdade o limite é o trigger no banco
  /// (`verificar_limite_usuarios_convite`).
  static const maxUsuariosPorProduto = {
    produtoTier1: 4,
    produtoTier2: 7,
  };
}
