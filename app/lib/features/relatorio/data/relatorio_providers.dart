import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'relatorio_repository.dart';

final relatorioRepositoryProvider = Provider<RelatorioRepository>((ref) {
  return RelatorioRepository(Supabase.instance.client);
});

final relatorioAstronautasProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(relatorioRepositoryProvider).listarRelatorioAstronautas();
});
