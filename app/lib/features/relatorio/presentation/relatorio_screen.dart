import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/relatorio_providers.dart';

class RelatorioScreen extends ConsumerWidget {
  const RelatorioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatorio = ref.watch(relatorioAstronautasProvider);

    return Scaffold(
      body: relatorio.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhum astronauta cadastrado ainda.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(relatorioAstronautasProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              itemBuilder: (context, index) {
                final astronauta = lista[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          astronauta['nome_exibicao'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('${astronauta['saldo_moedas']} moedas no saldo'),
                        Text(
                          '${astronauta['missoes_concluidas']} missões concluídas · '
                          '${astronauta['missoes_em_aberto']} em aberto',
                        ),
                        Text('${astronauta['premios_conquistados']} prêmios conquistados'),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}
