import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_specs.dart';
import '../tokens/app_typography.dart';

/// Botão de ação primária do Design System "Starlight" — fundo
/// `stardustYellow` com glow sutil, pro CTA principal de cada tela.
class PrimarySpaceButton extends StatelessWidget {
  const PrimarySpaceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: AppSpecs.glowYellow,
        borderRadius: BorderRadius.circular(AppSpecs.radiusM),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.stardustYellow,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          ),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.textOnPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppSpecs.spaceS),
                  ],
                  Text(label, style: AppTypography.buttonLabel),
                ],
              ),
      ),
    );
  }
}
