import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_specs.dart';
import '../tokens/app_typography.dart';

/// Tema global "Starlight". Cobre não só os componentes novos
/// (`PrimarySpaceButton`, `CoinBadge`, `MissionCard`) mas também os
/// widgets Material padrão que as telas já existentes usam
/// (`TextFormField`, `Checkbox`, `Drawer`, `AlertDialog`, `SnackBar`) —
/// sem isso, metade do app ficaria "Starlight" e a outra metade no roxo
/// default do Material.
class AppTheme {
  static ThemeData get spaceRoutTheme {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    final colorScheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.stardustYellow,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.stardustYellow,
      onPrimaryContainer: AppColors.textOnPrimary,
      secondary: AppColors.nebulaLilac,
      onSecondary: AppColors.textPrimary,
      secondaryContainer: AppColors.surfaceCard,
      onSecondaryContainer: AppColors.textPrimary,
      error: AppColors.superNovaRed,
      onError: AppColors.textOnPrimary,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.textPrimary,
      outline: AppColors.surfaceBorder,
    );

    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
            .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
            .copyWith(
              headlineSmall: AppTypography.displayHeader,
              titleLarge: AppTypography.displayHeader,
              titleMedium: AppTypography.cardTitle,
              bodyMedium: AppTypography.bodyText,
              labelLarge: AppTypography.buttonLabel.copyWith(color: AppColors.textPrimary),
            );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.spaceDark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryColor: AppColors.stardustYellow,
      cardColor: AppColors.surfaceCard,
      dividerColor: AppColors.surfaceBorder,
      splashFactory: InkRipple.splashFactory,

      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: AppSpecs.spaceM, vertical: AppSpecs.spaceS),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.spaceDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.displayHeader.copyWith(fontSize: 20),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      iconTheme: const IconThemeData(color: AppColors.textSecondary),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surfaceCard,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        selectedColor: AppColors.stardustYellow,
        selectedTileColor: AppColors.stardustYellow.withValues(alpha: 0.12),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        labelStyle: AppTypography.bodyText,
        hintStyle: AppTypography.bodyText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpecs.spaceM,
          vertical: AppSpecs.spaceM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          borderSide: const BorderSide(color: AppColors.stardustYellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          borderSide: const BorderSide(color: AppColors.superNovaRed),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.stardustYellow
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.textOnPrimary),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusS),
        ),
      ),

      // O app só usa `FilledButton` (nunca `ElevatedButton` puro) — por isso
      // é `filledButtonTheme`, não `elevatedButtonTheme`, que precisa levar
      // a cor primária. `PrimarySpaceButton` cobre o CTA único de cada tela
      // (com glow e loading embutido); este tema cobre os `FilledButton`
      // compactos usados dentro de cards/listas/diálogos, que não cabem no
      // formato full-width do `PrimarySpaceButton`.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.stardustYellow,
          foregroundColor: AppColors.textOnPrimary,
          textStyle: AppTypography.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.stardustYellow,
          textStyle: AppTypography.buttonLabel.copyWith(color: AppColors.stardustYellow),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpecs.radiusM),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        titleTextStyle: AppTypography.cardTitle,
        contentTextStyle: AppTypography.bodyText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusL),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpecs.radiusL)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceCard,
        contentTextStyle: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.stardustYellow,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.stardustYellow,
        foregroundColor: AppColors.textOnPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpecs.radiusM),
        ),
      ),
    );
  }
}
