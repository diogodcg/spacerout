import 'package:supabase_flutter/supabase_flutter.dart';

/// Onboarding de organização nova (PLANO_MIGRACAO.md §5.3). Convites (§5.2)
/// são aceitos automaticamente por trigger no login — não passam por aqui.
class OrganizacaoRepository {
  OrganizacaoRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Null quando o usuário logado ainda não tem linha em `usuarios` — nem
  /// por convite aceito automaticamente, nem por onboarding anterior.
  Future<Map<String, dynamic>?> buscarUsuarioAtual() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return Future.value(null);
    return _supabase.from('usuarios').select().eq('id', uid).maybeSingle();
  }

  Future<void> criarOrganizacao(String nome) {
    return _supabase.rpc('criar_organizacao', params: {'p_nome': nome});
  }
}
