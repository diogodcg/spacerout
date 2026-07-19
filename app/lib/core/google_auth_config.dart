/// Client ID "Web" criado no Google Cloud Console (APIs & Services >
/// Credentials > OAuth client ID > Web application), usado como
/// `serverClientId` para o google_sign_in obter um idToken que o Supabase
/// aceita. O MESMO valor precisa ser colado no Supabase Dashboard em
/// Authentication > Providers > Google > Client IDs.
///
/// Ainda não configurado — ver checklist no README.
class GoogleAuthConfig {
  static const webClientId = 'SUBSTITUIR_PELO_WEB_CLIENT_ID.apps.googleusercontent.com';
}
