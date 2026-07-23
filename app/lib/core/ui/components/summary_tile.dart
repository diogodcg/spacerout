import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_specs.dart';
import '../tokens/app_typography.dart';

/// Cartão de resumo usado nas telas de Início (responsável e astronauta) —
/// um número em destaque + rótulo, com ícone temático à esquerda.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpecs.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpecs.radiusM),
        boxShadow: AppSpecs.cardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.stardustYellow, size: 28),
          const SizedBox(width: AppSpecs.spaceM),
          Text('$value', style: AppTypography.displayHeader.copyWith(fontSize: 22)),
          const SizedBox(width: AppSpecs.spaceS),
          Expanded(child: Text(label, style: AppTypography.bodyText)),
        ],
      ),
    );
  }
}
