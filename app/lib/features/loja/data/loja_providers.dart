import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../organizacao/data/organizacao_providers.dart';
import 'loja_repository.dart';

final lojaRepositoryProvider = Provider<LojaRepository>((ref) {
  return LojaRepository(Supabase.instance.client);
});

/// Com uma criança selecionada, mostra só os suprimentos atribuídos a ela
/// exclusivamente — "Visão geral" (null) mostra o catálogo todo.
final premiosListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final lista = await ref.watch(lojaRepositoryProvider).listarPremios();
  final crianca = ref.watch(criancaSelecionadaProvider);
  if (crianca == null) return lista;
  return lista.where((p) => p['atribuido_a'] == crianca).toList();
});

/// Com uma criança selecionada, mostra só os resgates feitos por ela.
final resgatesPendentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final lista = await ref.watch(lojaRepositoryProvider).listarResgatesPendentes();
  final crianca = ref.watch(criancaSelecionadaProvider);
  if (crianca == null) return lista;
  return lista.where((r) => r['resgatado_por'] == crianca).toList();
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
