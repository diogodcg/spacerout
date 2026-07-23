import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/coin_badge.dart';
import '../../../core/ui/components/stellar_mascot.dart';
import '../../../core/ui/components/summary_tile.dart';
import '../../../core/ui/tokens/app_specs.dart';
import '../../../core/ui/tokens/app_typography.dart';
import '../../missoes/data/missoes_providers.dart';
import '../../organizacao/data/organizacao_providers.dart';

/// Tela de boas-vindas do astronauta — saldo de moedas + resumo das
/// missões, pra não cair direto em "Missões" sem nenhum contexto.
class HomeAstronautaScreen extends ConsumerWidget {
  const HomeAstronautaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(usuarioAtualProvider).value;
    final nome = usuario?['nome_exibicao'] as String?;
    final saldo = usuario?['saldo_moedas'] as int? ?? 0;
    final missoes = ref.watch(missoesAstronautaProvider).value ?? const [];
    final disponiveis = missoes.where((m) => m['status'] == 'disponivel').length;
    final aguardando = missoes.where((m) => m['status'] == 'enviada').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpecs.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: StellarMascot(size: 96, trail: true)),
          const SizedBox(height: AppSpecs.spaceM),
          Text(
            nome == null ? 'Olá!' : 'Olá, $nome!',
            style: AppTypography.displayHeader,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpecs.spaceXS),
          Text(
            'Pronto pra mais uma missão?',
            style: AppTypography.bodyText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpecs.spaceM),
          Center(child: CoinBadge(coins: saldo)),
          const SizedBox(height: AppSpecs.spaceXL),
          SummaryTile(
            icon: Icons.rocket_launch,
            value: disponiveis,
            label: disponiveis == 1
                ? 'missão disponível pra você'
                : 'missões disponíveis pra você',
          ),
          const SizedBox(height: AppSpecs.spaceM),
          SummaryTile(
            icon: Icons.hourglass_top_rounded,
            value: aguardando,
            label: aguardando == 1
                ? 'missão aguardando aprovação'
                : 'missões aguardando aprovação',
          ),
        ],
      ),
    );
  }
}
