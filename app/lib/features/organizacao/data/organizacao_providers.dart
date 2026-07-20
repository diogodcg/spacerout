import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'organizacao_repository.dart';

final organizacaoRepositoryProvider = Provider<OrganizacaoRepository>((ref) {
  return OrganizacaoRepository(Supabase.instance.client);
});

/// Null enquanto o usuário logado não tem linha em `usuarios` — sinal para
/// o `_AuthGate` mostrar o onboarding em vez do app autenticado.
final usuarioAtualProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(organizacaoRepositoryProvider).buscarUsuarioAtual();
});

final astronautasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(organizacaoRepositoryProvider).listarAstronautas();
});

/// Criança (astronauta) que o responsável está "vendo" no painel — null
/// significa "Visão geral" (todo mundo misturado, como antes de existir o
/// seletor). Persiste entre trocas de tela dentro do painel do responsável.
final criancaSelecionadaProvider = StateProvider<String?>((ref) => null);
