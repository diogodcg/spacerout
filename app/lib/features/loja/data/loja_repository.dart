import 'package:supabase_flutter/supabase_flutter.dart';

/// Cadastro de prêmios e validação de resgates pelo responsável
/// (`suprimentos_cosmicos` / `resgates_suprimentos`). O resgate em si é
/// criado pelo astronauta (débito atômico via trigger
/// `processar_resgate_suprimento`); aqui só confirmamos a entrega.
class LojaRepository {
  LojaRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> listarPremios() async {
    final rows = await _supabase
        .from('suprimentos_cosmicos')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> listarResgatesPendentes() async {
    final rows = await _supabase
        .from('resgates_suprimentos')
        .select()
        .eq('status', 'solicitado')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> criarPremio({
    required String organizacaoId,
    required String nome,
    required int custoMoedas,
  }) {
    return _supabase.from('suprimentos_cosmicos').insert({
      'organizacao_id': organizacaoId,
      'nome': nome,
      'custo_moedas': custoMoedas,
      'criado_por': _supabase.auth.currentUser!.id,
    });
  }

  Future<void> atualizarPremio(
    String id, {
    required String nome,
    required int custoMoedas,
  }) {
    return _supabase.from('suprimentos_cosmicos').update({
      'nome': nome,
      'custo_moedas': custoMoedas,
    }).eq('id', id);
  }

  Future<void> definirAtivo(String id, bool ativo) {
    return _supabase.from('suprimentos_cosmicos').update({'ativo': ativo}).eq('id', id);
  }

  /// A FK de `resgates_suprimentos.suprimento_id` é `on delete restrict` —
  /// o banco recusa excluir um suprimento com histórico de resgate.
  Future<void> excluirPremio(String id) {
    return _supabase.from('suprimentos_cosmicos').delete().eq('id', id);
  }

  Future<void> confirmarEntrega(String id) {
    return _supabase.from('resgates_suprimentos').update({
      'status': 'entregue',
      'entregue_por': _supabase.auth.currentUser!.id,
      'data_entrega': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<Map<String, String>> nomesPremios(Iterable<String> ids) async {
    final idsUnicos = ids.toSet().toList();
    if (idsUnicos.isEmpty) return {};
    final rows = await _supabase
        .from('suprimentos_cosmicos')
        .select('id, nome')
        .inFilter('id', idsUnicos);
    return {for (final row in rows) row['id'] as String: row['nome'] as String};
  }

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
}
