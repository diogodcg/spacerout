import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografia do Design System "Starlight".
///
/// Par: Space Grotesk pros elementos de "painel de comando" (headers,
/// títulos de card, botões) e Plus Jakarta Sans pro corpo de texto, que
/// precisa de leitura confortável tanto pra criança quanto pra adulto.
/// Space Mono no contador de moedas por ter algarismos de largura fixa
/// (não "pula" quando o saldo muda) — e por ser a fonte-irmã da Space
/// Grotesk (mesma família de design, batizada "Space").
class AppTypography {
  static TextStyle get displayHeader => GoogleFonts.spaceGrotesk(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get cardTitle => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyText => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get buttonLabel => GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnPrimary,
  );

  static TextStyle get coinCounter => GoogleFonts.spaceMono(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.stardustYellow,
  );
}
