import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // GoogleSignIn.instance.initialize() só pode ser chamado uma vez por
  // sessão do app — uma segunda chamada trava/lança erro (documentado no
  // pacote). Memoiza a Future em vez de chamar de novo a cada login.
  Future<void>? _googleInitFuture;

  // O nonce só pode ser definido em initialize(), não em authenticate() —
  // e initialize() só roda uma vez por sessão do app, então o nonce fica
  // fixo pra sessão inteira (não é regenerado a cada tentativa de login).
  // Supabase exige receber o valor cru e re-hasheá-lo (SHA-256) pra
  // comparar com o claim `nonce` do idToken; por isso mandamos o hash pro
  // Google e o valor cru pro Supabase.
  final String _rawNonce = _generateRawNonce();

  static String _generateRawNonce() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _hashNonce(String rawNonce) =>
      sha256.convert(utf8.encode(rawNonce)).toString();

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= GoogleSignIn.instance.initialize(
      // Web usa `clientId`; as demais plataformas usam `serverClientId` (o
      // mesmo Web Client ID, usado pra validar o idToken no Supabase) — o
      // pacote lança erro se os dois forem passados juntos no Web.
      clientId: kIsWeb ? GoogleAuthConfig.webClientId : null,
      serverClientId: kIsWeb ? null : GoogleAuthConfig.webClientId,
      nonce: _hashNonce(_rawNonce),
    );
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Não foi possível obter o idToken do Google.');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: _rawNonce,
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
