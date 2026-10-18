import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData ldtLightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: LdtColors.primary,
    brightness: Brightness.light,
    primary: LdtColors.primary,
    onPrimary: Colors.white,
    secondary: const Color(0xFF4DA68A),
    surface: LdtColors.surface,
    onSurface: LdtColors.textPrimary,
    error: LdtColors.error,
    outline: LdtColors.outline,
  );

  return _buildTheme(base, isLight: true);
}

ThemeData ldtDarkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: LdtColors.primary,
    brightness: Brightness.dark,
    primary: LdtColors.primaryDark,
    onPrimary: LdtColors.backgroundDark,
    secondary: const Color(0xFF5CB898),
    surface: LdtColors.surfaceDark,
    onSurface: LdtColors.textPrimaryDark,
    error: const Color(0xFFFFB4AB),
    outline: LdtColors.outlineDark,
  );

  return _buildTheme(base, isLight: false);
}

ThemeData _buildTheme(ColorScheme cs, {required bool isLight}) {
  final bg = isLight ? LdtColors.background : LdtColors.backgroundDark;
  final cardBg = isLight ? LdtColors.surface : LdtColors.surfaceDark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: bg,

    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: LdtTextStyles.headline.copyWith(
        color: cs.onSurface,
      ),
      iconTheme: IconThemeData(color: cs.onSurface),
    ),

    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LdtRadius.lg),
        side: BorderSide(
          color: isLight ? LdtColors.outline : LdtColors.outlineDark,
        ),
      ),
      margin: EdgeInsets.zero,
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LdtRadius.md),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? LdtColors.surfaceVariant : LdtColors.surfaceVariantDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LdtRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LdtRadius.md),
        borderSide: BorderSide(
          color: isLight ? LdtColors.outline : LdtColors.outlineDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LdtRadius.md),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LdtRadius.md),
        borderSide: BorderSide(color: cs.error),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LdtSpacing.md,
        vertical: LdtSpacing.sm + 4,
      ),
      labelStyle: LdtTextStyles.bodyMedium.copyWith(
        color: isLight ? LdtColors.textSecondary : LdtColors.textSecondaryDark,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LdtRadius.md),
        ),
        textStyle: LdtTextStyles.labelLarge,
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LdtRadius.md),
        ),
        side: BorderSide(color: cs.outline),
        textStyle: LdtTextStyles.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: LdtTextStyles.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LdtRadius.sm),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LdtRadius.md),
        ),
        textStyle: LdtTextStyles.labelLarge,
      ),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LdtRadius.full),
      ),
      labelStyle: LdtTextStyles.labelSmall,
    ),

    dividerTheme: DividerThemeData(
      color: isLight ? LdtColors.outline : LdtColors.outlineDark,
      thickness: 1,
      space: 1,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardBg,
      indicatorColor: cs.primary.withAlpha(30),
      labelTextStyle: WidgetStateProperty.all(LdtTextStyles.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: cs.primary);
        }
        return IconThemeData(
          color: isLight ? LdtColors.textSecondary : LdtColors.textSecondaryDark,
        );
      }),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardBg,
      selectedItemColor: cs.primary,
      unselectedItemColor: isLight ? LdtColors.textSecondary : LdtColors.textSecondaryDark,
      type: BottomNavigationBarType.fixed,
    ),

    textTheme: TextTheme(
      displayLarge: LdtTextStyles.displayLarge,
      headlineMedium: LdtTextStyles.headline,
      titleLarge: LdtTextStyles.titleLarge,
      titleMedium: LdtTextStyles.titleMedium,
      bodyLarge: LdtTextStyles.bodyLarge,
      bodyMedium: LdtTextStyles.bodyMedium,
      labelLarge: LdtTextStyles.labelLarge,
      labelSmall: LdtTextStyles.labelSmall,
    ).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    ),
  );
}
