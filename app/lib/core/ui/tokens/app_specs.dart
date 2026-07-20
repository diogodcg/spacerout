import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Geometria, espaçamentos e sombras do Design System "Starlight".
class AppSpecs {
  // Raios de curvatura
  static const double radiusS = 8.0; // Badges e tags
  static const double radiusM = 16.0; // Cards, botões e inputs (padrão)
  static const double radiusL = 24.0; // BottomSheet e dialogs

  // Espaçamentos
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;

  // Sombras (efeito cósmico sutil — Calm Technology, sem exagero)
  static List<BoxShadow> glowYellow = [
    BoxShadow(
      color: AppColors.stardustYellow.withValues(alpha: 0.2),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}
