import 'package:flutter/material.dart';

/// Paleta do Design System "Starlight" — dark-first, nomes amarrados ao
/// vocabulário que o schema já usa (missões, moedas, comprovações).
class AppColors {
  // --- FUNDOS (Backgrounds) ---
  static const Color spaceDark = Color(0xFF101223); // Fundo principal (canvas)
  static const Color surfaceCard = Color(0xFF1A1D36); // Cards, modais, drawer
  static const Color surfaceBorder = Color(0xFF2A2E52); // Bordas e divisores

  // --- ACENTOS E ESTADOS (Brand & Feedback) ---
  static const Color stardustYellow = Color(0xFFFFE082); // Ação primária, moedas
  static const Color auroraGreen = Color(0xFFA5D6A7); // Sucesso, missão aprovada
  static const Color nebulaLilac = Color(0xFF9C8EB9); // Secundário, inativo
  static const Color superNovaRed = Color(0xFFFF8A80); // Rejeição, alerta

  // --- TEXTO ---
  static const Color textPrimary = Color(0xFFF4F5F7); // Títulos, contraste máximo
  static const Color textSecondary = Color(0xFFA0A5C0); // Descrições, rótulos
  static const Color textOnPrimary = Color(0xFF101223); // Texto sobre stardustYellow
}
