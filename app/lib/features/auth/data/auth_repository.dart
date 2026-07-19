import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/google_auth_config.dart';

/// Login social (Google / Apple), trocando o idToken do provedor pela
/// sessão do Supabase. Ver PLANO_MIGRACAO.md §5 para o porquê da escolha
/// (login social em vez de usuário/senha).
class AuthRepository {
  AuthRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<void> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: GoogleAuthConfig.webClientId);

    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Não foi possível obter o idToken do Google.');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Não foi possível obter o idToken da Apple.');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  Future<void> signOut() => _supabase.auth.signOut();
}
