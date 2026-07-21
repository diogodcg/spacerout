import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/coin_badge.dart';
import '../../../core/ui/components/empty_state.dart';
import '../../organizacao/data/organizacao_providers.dart';
import '../data/loja_providers.dart';

/// Loja do astronauta: saldo de moedas + suprimentos ativos disponíveis pra
/// resgate. Resgatar cria a linha em `resgates_suprimentos`; o débito e a
/// checagem de saldo são atômicos no trigger `processar_resgate_suprimento`.
class LojaAstronautaScreen extends ConsumerWidget {
  const LojaAstronautaScreen({super.key});

  Future<void> _resgatar(BuildContext context, WidgetRef ref, Map<String, dynamic> suprimento) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resgatar?'),
        content: Text(
          'Resgatar "${suprimento['nome']}" por ${suprimento['custo_moedas']} moedas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resgatar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      final usuario = ref.read(usuarioAtualProvider).value;
      await ref.read(lojaRepositoryProvider).criarResgate(
            organizacaoId: usuario!['organizacao_id'] as String,
            suprimentoId: suprimento['id'] as String,
          );
      ref.invalidate(suprimentosAtivosProvider);
      ref.invalidate(usuarioAtualProvider);
      ref.invalidate(meusResgatesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível resgatar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suprimentos = ref.watch(suprimentosAtivosProvider);
    final saldo = ref.watch(usuarioAtualProvider).value?['saldo_moedas'] as int? ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Saldo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              CoinBadge(coins: saldo),
            ],
          ),
        ),
        Expanded(
          child: suprimentos.when(
            data: (lista) {
              if (lista.isEmpty) {
                return const EmptyState(
                  title: 'Loja vazia',
                  message: 'Nenhum suprimento disponível ainda. Volte mais tarde!',
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(suprimentosAtivosProvider.future),
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    final suprimento = lista[index];
                    final custo = suprimento['custo_moedas'] as int;
                    return ListTile(
                      title: Text(suprimento['nome'] as String),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: CoinBadge(coins: custo),
                      ),
                      trailing: FilledButton(
                        onPressed: saldo >= custo ? () => _resgatar(context, ref, suprimento) : null,
                        child: const Text('Resgatar'),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Erro: $error')),
          ),
        ),
      ],
    );
  }
}
