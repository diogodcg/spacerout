import 'package:flutter/material.dart';

import '../tokens/app_specs.dart';
import '../tokens/app_typography.dart';
import 'stellar_mascot.dart';

/// Ilustração padrão pra listas vazias (missões, pedidos, etc.) — o Stellar
/// com rastro de cometa, um título curto e uma explicação do que falta.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpecs.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StellarMascot(size: 72, trail: true),
            const SizedBox(height: AppSpecs.spaceM),
            Text(title, style: AppTypography.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpecs.spaceXS),
            Text(message, style: AppTypography.bodyText, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
