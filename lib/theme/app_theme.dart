import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _seed = Color(0xFF1A56DB);
  static const _secondary = Color(0xFF0E9F9F);
  static const _tertiary = Color(0xFF7E3AF2);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
        secondary: _secondary,
        tertiary: _tertiary,
      ),
    );
    final text = GoogleFonts.beVietnamProTextTheme(base.textTheme);
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: base.colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: base.colorScheme.onSurface,
        titleTextStyle: GoogleFonts.beVietnamPro(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: base.colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: base.colorScheme.outlineVariant.withOpacity(0.65),
          ),
        ),
        color: base.colorScheme.surface.withOpacity(0.92),
      ),
      dividerTheme: DividerThemeData(
        color: base.colorScheme.outlineVariant.withOpacity(0.5),
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: base.colorScheme.primary, width: 2),
        ),
        labelStyle: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  static BoxDecoration pageGradient(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c.primary.withOpacity(0.08),
          c.secondary.withOpacity(0.06),
          c.surface,
        ],
        stops: const [0.0, 0.4, 1.0],
      ),
    );
  }

  static BoxDecoration glassCard(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: c.surface.withOpacity(0.88),
      border: Border.all(color: c.outlineVariant.withOpacity(0.55)),
      boxShadow: [
        BoxShadow(
          color: c.primary.withOpacity(0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
