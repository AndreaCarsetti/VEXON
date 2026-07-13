import 'package:flutter/material.dart';

/// Palette colori ufficiale VEXON — estratta dal logo e completata
/// con colori semantici per stati hardware/gioco.
class VexonColors {
  VexonColors._();

  // Brand
  static const Color brandRed = Color(0xFFE63E42);       // accenti, CTA, "in gioco"
  static const Color shadowRed = Color(0xFF7A282D);      // gradienti, bordi hover

  // Superfici
  static const Color background = Color(0xFF0A0A0C);     // sfondo principale
  static const Color surface = Color(0xFF16171B);        // card, pannelli, sidebar
  static const Color surfaceElevated = Color(0xFF1F2025); // card in evidenza/hover

  // Testo e metallo
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF9B9CA3);   // steel grey
  static const Color textDisabled = Color(0xFF5A5B61);

  // Stati semantici (dashboard hardware)
  static const Color success = Color(0xFF3DDC84);   // temperature/utilizzo OK
  static const Color warning = Color(0xFFFFB020);   // utilizzo medio-alto
  static const Color critical = Color(0xFFFF3B30);  // overheat, utilizzo critico
  static const Color info = Color(0xFF4D9DE0);      // notifiche, update

  // Gradiente per il glow del logo/elementi hero
  static const LinearGradient brandGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [brandRed, shadowRed],
  );

  /// ThemeData base pronto all'uso
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: brandRed,
        colorScheme: const ColorScheme.dark(
          primary: brandRed,
          secondary: shadowRed,
          surface: surface,
          error: critical,
          onPrimary: textPrimary,
          onSurface: textPrimary,
        ),
        cardColor: surface,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary),
        ),
      );
}
