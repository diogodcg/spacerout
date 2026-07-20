import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/loja_providers.dart';

const _statusLabel = {
  'solicitado': 'Aguardando entrega',
  'entregue': 'Entregue',
};

/// Histórico de resgates do astronauta logado, com o status de cada um
/// (o responsável confirma a entrega física do prêmio).
class MeusPedidosScreen extends ConsumerWidget {
  const MeusPedidosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resgates = ref.watch(meusResgatesProvider);
    final nomes = ref.watch(meusResgatesNomesProvider);

    return resgates.when(
      data: (lista) {
        if (lista.isEmpty) {
          return const Center(child: Text('Nenhum pedido ainda.'));
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(meusResgatesProvider.future),
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final resgate = lista[index];
              final nome = nomes.value?[resgate['suprimento_id']];
              return ListTile(
                title: Text(nome ?? '...'),
                subtitle: Text(
                  '${resgate['moedas_gastas']} moedas · '
                  '${_statusLabel[resgate['status']]}',
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
