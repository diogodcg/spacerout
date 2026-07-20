import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro de device tokens FCM (`dispositivos_notificacao`,
/// PLANO_MIGRACAO.md §5.1). Escopo Android apenas por enquanto — iOS
/// bloqueado por falta de APNs Authentication Key (Apple Developer
/// Program pago).
class NotificacoesRepository {
  NotificacoesRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Upsert por `fcm_token` (coluna `unique`): o mesmo token nunca duplica
  /// linha, e se o aparelho trocar de conta o token é revinculado ao novo
  /// usuário.
  Future<void> registrarToken(String fcmToken) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await _supabase.from('dispositivos_notificacao').upsert(
      {
        'usuario_id': uid,
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
  }
}
