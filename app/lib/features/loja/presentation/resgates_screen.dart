import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/coin_badge.dart';
import '../../../core/ui/components/empty_state.dart';
import '../data/loja_providers.dart';

/// Fila de resgates solicitados pelos astronautas (`status = 'solicitado'`),
/// aguardando o responsável confirmar a entrega física do prêmio.
class ResgatesScreen extends ConsumerWidget {
  const ResgatesScreen({super.key});

  Future<void> _confirmar(WidgetRef ref, String id) async {
    await ref.read(lojaRepositoryProvider).confirmarEntrega(id);
    ref.invalidate(resgatesPendentesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resgates = ref.watch(resgatesPendentesProvider);
    final nomes = ref.watch(resgatesNomesProvider);

    return resgates.when(
      data: (lista) {
        if (lista.isEmpty) {
          return const EmptyState(
            title: 'Tudo em dia',
            message: 'Nenhum resgate esperando confirmação no momento.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(resgatesPendentesProvider.future),
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final resgate = lista[index];
              final id = resgate['id'] as String;
              final premioNome = nomes.value?.premios[resgate['suprimento_id']];
              final usuarioNome = nomes.value?.usuarios[resgate['resgatado_por']];

              return ListTile(
                title: Text(premioNome ?? '...'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      CoinBadge(coins: resgate['moedas_gastas'] as int),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Resgatado por: ${usuarioNome ?? '...'}')),
                    ],
                  ),
                ),
                trailing: FilledButton(
                  onPressed: () => _confirmar(ref, id),
                  child: const Text('Confirmar entrega'),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}
