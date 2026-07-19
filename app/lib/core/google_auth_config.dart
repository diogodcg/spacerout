/// Client ID "Web" criado no Google Cloud Console (APIs & Services >
/// Credentials > OAuth client ID > Web application), usado como
/// `serverClientId` para o google_sign_in obter um idToken que o Supabase
/// aceita. O MESMO valor precisa ser colado no Supabase Dashboard em
/// Authentication > Providers > Google > Client IDs.
class GoogleAuthConfig {
  static const webClientId = '740026619707-v1ltucdv9s5hhlk628dm5m90g1jo6dk7.apps.googleusercontent.com';
}
