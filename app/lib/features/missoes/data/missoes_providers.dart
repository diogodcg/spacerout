import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'missoes_repository.dart';

final missoesRepositoryProvider = Provider<MissoesRepository>((ref) {
  return MissoesRepository(Supabase.instance.client);
});

final missoesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(missoesRepositoryProvider).listarMissoes();
});

final comprovacoesPendentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(missoesRepositoryProvider).listarComprovacoesPendentes();
});

/// Nomes de quem enviou cada comprovação pendente, resolvidos em lote junto
/// com a lista (evita N+1 e embedding ambíguo do PostgREST).
final comprovacoesEnviadoPorNomesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final comprovacoes = await ref.watch(comprovacoesPendentesProvider.future);
  final ids = comprovacoes.map((c) => c['enviado_por'] as String);
  return ref.watch(missoesRepositoryProvider).nomesUsuarios(ids);
});
