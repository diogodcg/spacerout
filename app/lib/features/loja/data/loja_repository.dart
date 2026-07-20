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
    String? atribuidoA,
  }) {
    return _supabase.from('suprimentos_cosmicos').insert({
      'organizacao_id': organizacaoId,
      'nome': nome,
      'custo_moedas': custoMoedas,
      'atribuido_a': atribuidoA,
      'criado_por': _supabase.auth.currentUser!.id,
    });
  }

  Future<void> atualizarPremio(
    String id, {
    required String nome,
    required int custoMoedas,
    String? atribuidoA,
  }) {
    return _supabase.from('suprimentos_cosmicos').update({
      'nome': nome,
      'custo_moedas': custoMoedas,
      'atribuido_a': atribuidoA,
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

  /// Suprimentos ativos relevantes pro astronauta logado: em aberto pra
  /// qualquer um (`atribuido_a` nulo) ou atribuídos a ele — mesma lógica de
  /// `MissoesRepository.listarMissoesAstronauta`.
  Future<List<Map<String, dynamic>>> listarSuprimentosAtivos() async {
    final uid = _supabase.auth.currentUser!.id;
    final rows = await _supabase
        .from('suprimentos_cosmicos')
        .select()
        .eq('ativo', true)
        .or('atribuido_a.eq.$uid,atribuido_a.is.null')
        .order('custo_moedas', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// O trigger `processar_resgate_suprimento` faz a checagem de saldo e o
  /// débito atômico — se o saldo for insuficiente, o INSERT levanta exceção
  /// (ver PLANO_MIGRACAO.md / migration de histórico de resgates).
  Future<void> criarResgate({
    required String organizacaoId,
    required String suprimentoId,
  }) {
    return _supabase.from('resgates_suprimentos').insert({
      'organizacao_id': organizacaoId,
      'suprimento_id': suprimentoId,
      'resgatado_por': _supabase.auth.currentUser!.id,
    });
  }

  Future<List<Map<String, dynamic>>> listarMeusResgates() async {
    final uid = _supabase.auth.currentUser!.id;
    final rows = await _supabase
        .from('resgates_suprimentos')
        .select()
        .eq('resgatado_por', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
