import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/stellar_mascot.dart';
import '../../../core/ui/components/summary_tile.dart';
import '../../../core/ui/tokens/app_specs.dart';
import '../../../core/ui/tokens/app_typography.dart';
import '../../loja/data/loja_providers.dart';
import '../../missoes/data/missoes_providers.dart';
import '../../organizacao/data/organizacao_providers.dart';

/// Tela de boas-vindas do responsável — resumo do que espera aprovação/
/// confirmação, pra não cair direto em "Missões" sem nenhum contexto.
class HomeResponsavelScreen extends ConsumerWidget {
  const HomeResponsavelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nome = ref.watch(usuarioAtualProvider).value?['nome_exibicao'] as String?;
    final comprovacoes = ref.watch(comprovacoesPendentesProvider).value?.length ?? 0;
    final resgates = ref.watch(resgatesPendentesProvider).value?.length ?? 0;
    final astronautas = ref.watch(astronautasProvider).value?.length ?? 0;

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
            'Aqui está o resumo da sua base hoje.',
            style: AppTypography.bodyText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpecs.spaceXL),
          SummaryTile(
            icon: Icons.fact_check,
            value: comprovacoes,
            label: comprovacoes == 1
                ? 'comprovação aguardando aprovação'
                : 'comprovações aguardando aprovação',
          ),
          const SizedBox(height: AppSpecs.spaceM),
          SummaryTile(
            icon: Icons.shopping_bag,
            value: resgates,
            label: resgates == 1
                ? 'pedido aguardando confirmação'
                : 'pedidos aguardando confirmação',
          ),
          const SizedBox(height: AppSpecs.spaceM),
          SummaryTile(
            icon: Icons.groups,
            value: astronautas,
            label: astronautas == 1 ? 'astronauta na família' : 'astronautas na família',
          ),
        ],
      ),
    );
  }
}
