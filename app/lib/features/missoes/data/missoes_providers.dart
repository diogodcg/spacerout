import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../organizacao/data/organizacao_providers.dart';
import 'missoes_repository.dart';

final missoesRepositoryProvider = Provider<MissoesRepository>((ref) {
  return MissoesRepository(Supabase.instance.client);
});

/// Com uma criança selecionada, mostra só as missões atribuídas a ela
/// exclusivamente — "Visão geral" (null) mostra o catálogo todo, incluindo
/// as abertas pra qualquer astronauta.
final missoesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final lista = await ref.watch(missoesRepositoryProvider).listarMissoes();
  final crianca = ref.watch(criancaSelecionadaProvider);
  if (crianca == null) return lista;
  return lista.where((m) => m['atribuido_a'] == crianca).toList();
});

/// Com uma criança selecionada, mostra só as comprovações enviadas por ela.
final comprovacoesPendentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final lista = await ref.watch(missoesRepositoryProvider).listarComprovacoesPendentes();
  final crianca = ref.watch(criancaSelecionadaProvider);
  if (crianca == null) return lista;
  return lista.where((m) => m['enviado_por'] == crianca).toList();
});

/// Nomes de quem enviou cada comprovação pendente, resolvidos em lote junto
/// com a lista (evita N+1 e embedding ambíguo do PostgREST).
final comprovacoesEnviadoPorNomesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final comprovacoes = await ref.watch(comprovacoesPendentesProvider.future);
  final ids = comprovacoes.map((c) => c['enviado_por'] as String);
  return ref.watch(missoesRepositoryProvider).nomesUsuarios(ids);
});

final missoesAstronautaProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(missoesRepositoryProvider).listarMissoesAstronauta();
});
