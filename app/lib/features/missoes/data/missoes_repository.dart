import 'package:supabase_flutter/supabase_flutter.dart';

/// Cadastro de missões e aprovação de comprovações pelo responsável
/// (`coordenadas_voo`). Envio de comprovação pelo astronauta passa pela RPC
/// `enviar_comprovacao_missao` (não por aqui) — ver PLANO_MIGRACAO.md §5.5.2.
/// Cada linha é um ciclo de missão; a criação automática do próximo ciclo
/// (recorrência) é um job futuro, fora do escopo do cadastro em si.
class MissoesRepository {
  MissoesRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listarMissoes() async {
    final rows = await _supabase
        .from('coordenadas_voo')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listarComprovacoesPendentes() async {
    final rows = await _supabase
        .from('coordenadas_voo')
        .select()
        .eq('status', 'enviada')
        .order('data_envio', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> criarMissao({
    required String organizacaoId,
    required String titulo,
    required int moedas,
    required String recorrencia,
  }) {
    return _supabase.from('coordenadas_voo').insert({
      'organizacao_id': organizacaoId,
      'titulo': titulo,
      'moedas': moedas,
      'recorrencia': recorrencia,
      'criado_por': _supabase.auth.currentUser!.id,
    });
  }

  Future<void> atualizarMissao(
    String id, {
    required String titulo,
    required int moedas,
    required String recorrencia,
  }) {
    return _supabase.from('coordenadas_voo').update({
      'titulo': titulo,
      'moedas': moedas,
      'recorrencia': recorrencia,
    }).eq('id', id);
  }

  Future<void> definirAtiva(String id, bool ativa) {
    return _supabase.from('coordenadas_voo').update({'ativa': ativa}).eq('id', id);
  }

  /// RLS só permite excluir missões com `status = 'disponivel'` (nunca
  /// enviadas/aprovadas) — preserva a trilha de auditoria de moedas já
  /// creditadas. Ver migration `20260719220000_exclusao_missoes_disponiveis`.
  Future<void> excluirMissao(String id) {
    return _supabase.from('coordenadas_voo').delete().eq('id', id);
  }

  Future<void> validarComprovacao(String id, {required bool aprovada}) {
    return _supabase.from('coordenadas_voo').update({
      'status': aprovada ? 'aprovada' : 'rejeitada',
      'validado_por': _supabase.auth.currentUser!.id,
      'data_validacao': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Lookup de `nome_exibicao` por id, usado para mostrar quem enviou cada
  /// comprovação sem precisar lidar com embedding ambíguo do PostgREST
  /// (coordenadas_voo tem múltiplas FKs para usuarios).
  Future<Map<String, String>> nomesUsuarios(Iterable<String> ids) async {
    final idsUnicos = ids.toSet().toList();
    if (idsUnicos.isEmpty) return {};
    final rows = await _supabase
        .from('usuarios')
        .select('id, nome_exibicao')
        .inFilter('id', idsUnicos);
    return {
      for (final row in rows) row['id'] as String: row['nome_exibicao'] as String,
    };
  }

  /// Bucket `comprovacoes` é privado — precisa de URL assinada para exibir a
  /// foto. `foto_url` guarda o path, não uma URL pronta.
  Future<String> urlAssinadaComprovacao(String path) {
    return _supabase.storage.from('comprovacoes').createSignedUrl(path, 3600);
  }
}
