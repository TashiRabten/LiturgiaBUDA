import 'package:flutter/material.dart';

/// Paleta oficial do app — espelha BudaColors do home_screen.dart.
class BudaPalette {
  static const Color mainBlue      = Color(0xFF88A9CC);
  static const Color lightBlue     = Color(0xFFA8C4DC);
  static const Color slateBlue     = Color(0xFF5A7A9A);
  static const Color darkBlue      = Color(0xFF3E7EBE);
  static const Color bgDeep        = Color(0xFF2E4A6A);
  static const Color bgMid         = Color(0xFF3A5A7C);
  static const Color darkGoldenrod = Color(0xFFB8860B);
  static const Color gold          = Color(0xFFD4A843);
  static const Color goldSoft      = Color(0xFFE8C97A);
  static const Color goldenBrown   = Color(0xFF8B7355);
  static const Color buttonGold    = Color(0xFFBFAF7C);
  static const Color cardBege      = Color(0xFFF5EDD8);
  static const Color cardBorda     = Color(0xFF8B7355);
  static const Color textoEscuro   = Color(0xFF2C3252);
  static const Color textoMedio    = Color(0xFF5A6080);
  static const Color textoOuro     = Color(0xFFB8860B);
  static const Color toolbarBorder = Color(0xFF1E375A);
  static const Color pramanaRing   = Color(0xFFCC3300);
}

/// Tema completo BUDA — aplica em qualquer subárvore via Theme(data: budaTheme()).
ThemeData budaTheme() {
  const seed = BudaPalette.darkBlue;

  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: BudaPalette.pramanaRing,
    onPrimary: Colors.white,
    primaryContainer: BudaPalette.cardBege,
    onPrimaryContainer: BudaPalette.pramanaRing,
    secondary: BudaPalette.gold,
    onSecondary: BudaPalette.bgDeep,
    secondaryContainer: BudaPalette.goldSoft,
    onSecondaryContainer: BudaPalette.textoEscuro,
    tertiary: BudaPalette.darkGoldenrod,
    onTertiary: Colors.white,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: const Color(0xFFFDE7E7),
    onErrorContainer: const Color(0xFF8C1D18),
    surface: BudaPalette.cardBege,
    onSurface: BudaPalette.textoEscuro,
    surfaceContainerLowest: BudaPalette.cardBege,
    surfaceContainerLow: const Color(0xFFF0E5C8),
    surfaceContainer: const Color(0xFFE8DDB8),
    surfaceContainerHigh: const Color(0xFFE0D2A8),
    surfaceContainerHighest: const Color(0xFFD8C898),
    onSurfaceVariant: BudaPalette.textoMedio,
    outline: BudaPalette.goldenBrown,
    outlineVariant: BudaPalette.cardBorda,
    inverseSurface: BudaPalette.bgMid,
    onInverseSurface: BudaPalette.cardBege,
    inversePrimary: BudaPalette.gold,
    shadow: Colors.black,
    scrim: Colors.black54,
    surfaceTint: BudaPalette.pramanaRing,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BudaPalette.mainBlue,
    fontFamily: 'Serif',

    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: BudaPalette.bgMid,
      foregroundColor: BudaPalette.gold,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: BudaPalette.gold,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      iconTheme: IconThemeData(color: BudaPalette.gold),
      actionsIconTheme: IconThemeData(color: BudaPalette.gold),
    ),

    // ── NavigationBar (bottom) ──
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BudaPalette.bgMid,
      indicatorColor: BudaPalette.pramanaRing.withValues(alpha: 0.30),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? BudaPalette.gold : BudaPalette.lightBlue,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? BudaPalette.gold : BudaPalette.lightBlue,
          size: 22,
        );
      }),
    ),

    // ── Botões filled (ação principal) ──
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BudaPalette.pramanaRing,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // ── Botões outlined ──
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BudaPalette.darkGoldenrod,
        side: const BorderSide(color: BudaPalette.cardBorda, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // ── Botões text ──
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: BudaPalette.darkGoldenrod),
    ),

    // ── Inputs ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BudaPalette.cardBorda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: BudaPalette.cardBorda.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BudaPalette.pramanaRing, width: 2),
      ),
      labelStyle: const TextStyle(color: BudaPalette.textoMedio),
      hintStyle: TextStyle(color: BudaPalette.textoMedio.withValues(alpha: 0.6)),
      prefixIconColor: BudaPalette.darkGoldenrod,
    ),

    // ── Cards ──
    cardTheme: CardThemeData(
      color: BudaPalette.cardBege,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: BudaPalette.cardBorda.withValues(alpha: 0.25)),
      ),
    ),

    // ── Dialog ──
    dialogTheme: DialogThemeData(
      backgroundColor: BudaPalette.cardBege,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: BudaPalette.pramanaRing,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      contentTextStyle: const TextStyle(
        color: BudaPalette.textoEscuro,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // ── Snackbar ──
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: BudaPalette.bgDeep,
      contentTextStyle: TextStyle(color: BudaPalette.cardBege),
      actionTextColor: BudaPalette.gold,
      behavior: SnackBarBehavior.floating,
    ),

    // ── SegmentedButton ──
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: BudaPalette.textoMedio,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: BudaPalette.pramanaRing,
        side: BorderSide(color: BudaPalette.cardBorda.withValues(alpha: 0.4)),
      ),
    ),

    // ── Divider ──
    dividerTheme: DividerThemeData(
      color: BudaPalette.cardBorda.withValues(alpha: 0.25),
      thickness: 1,
      space: 1,
    ),

    // ── IconButton ──
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: BudaPalette.darkGoldenrod),
    ),

    // ── PopupMenu ──
    popupMenuTheme: PopupMenuThemeData(
      color: BudaPalette.cardBege,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: BudaPalette.cardBorda.withValues(alpha: 0.3)),
      ),
      textStyle: const TextStyle(color: BudaPalette.textoEscuro, fontSize: 13),
    ),

    // ── ListTile ──
    listTileTheme: const ListTileThemeData(
      iconColor: BudaPalette.darkGoldenrod,
      textColor: BudaPalette.textoEscuro,
    ),

    // ── ProgressIndicator ──
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BudaPalette.pramanaRing,
    ),

    primarySwatch: const MaterialColor(0xFFCC3300, {
      50:  Color(0xFFFCEAE5),
      100: Color(0xFFF7C4B5),
      200: Color(0xFFF09B81),
      300: Color(0xFFE9714C),
      400: Color(0xFFE15324),
      500: Color(0xFFCC3300),
      600: Color(0xFFBA2D00),
      700: Color(0xFFA22600),
      800: Color(0xFF8B1F00),
      900: Color(0xFF6B1300),
    }),
  );
}
