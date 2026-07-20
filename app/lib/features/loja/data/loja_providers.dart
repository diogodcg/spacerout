import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loja_repository.dart';

final lojaRepositoryProvider = Provider<LojaRepository>((ref) {
  return LojaRepository(Supabase.instance.client);
});

final premiosListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(lojaRepositoryProvider).listarPremios();
});

final resgatesPendentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(lojaRepositoryProvider).listarResgatesPendentes();
});

/// Nomes de prêmio e de quem resgatou, resolvidos em lote junto com a lista
/// de resgates pendentes (evita N+1 e embedding ambíguo do PostgREST).
final resgatesNomesProvider =
    FutureProvider.autoDispose<({Map<String, String> premios, Map<String, String> usuarios})>(
        (ref) async {
  final resgates = await ref.watch(resgatesPendentesProvider.future);
  final repo = ref.watch(lojaRepositoryProvider);
  final premios = await repo.nomesPremios(resgates.map((r) => r['suprimento_id'] as String));
  final usuarios =
      await repo.nomesUsuarios(resgates.map((r) => r['resgatado_por'] as String));
  return (premios: premios, usuarios: usuarios);
});

final suprimentosAtivosProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(lojaRepositoryProvider).listarSuprimentosAtivos();
});

final meusResgatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(lojaRepositoryProvider).listarMeusResgates();
});

/// Nomes de prêmio pros meus resgates (ver resgatesNomesProvider — mesma
/// ideia, mas sem precisar do nome de quem resgatou, já que é sempre eu).
final meusResgatesNomesProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final resgates = await ref.watch(meusResgatesProvider.future);
  return ref
      .watch(lojaRepositoryProvider)
      .nomesPremios(resgates.map((r) => r['suprimento_id'] as String));
});
