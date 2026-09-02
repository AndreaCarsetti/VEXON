import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'vexon_colors.dart';

/// Sistema tipografico VEXON — due famiglie, ruoli precisi.
///
/// Prima c'erano tre font in giro senza criterio: il default Material
/// (titoli, menu, dialoghi), VT323 (solo l'orologio) e 'monospace' generico
/// del sistema operativo (solo l'HUD hardware). Il risultato era
/// un'interfaccia che sembrava assemblata a pezzi invece che un unico
/// "sistema operativo" coerente con il logo (lama cromata/rossa, taglio
/// netto, tecnico).
///
/// Ora ci sono solo due famiglie, ognuna con un compito preciso:
///
/// - **Rajdhani** — sans condensato, angolare, "tecnico" senza sembrare un
///   display da calcolatrice. Usato per TUTTO il testo dell'interfaccia:
///   titoli, nomi dei giochi, pulsanti, dialoghi, hint. Sostituisce il
///   default Material ovunque, tramite il [ThemeData] in [VexonColors].
/// - **VT323** — font digitale a 7 segmenti, già usato per l'orologio.
///   Esteso a TUTTI i valori numerici "da HUD": percentuali, gradi,
///   uptime, contatori sessione. È il font che dice "questo è un dato
///   letto in tempo reale dall'hardware", coerente ovunque compaia.
///
/// Non aggiungere altri fontFamily/GoogleFonts.* fuori da questo file:
/// se serve un nuovo stile, aggiungilo qui come metodo statico.
class VexonTypography {
  VexonTypography._();

  // ---------------------------------------------------------------------
  // Rajdhani — testo dell'interfaccia
  // ---------------------------------------------------------------------

  /// Titolo hero — per un eventuale testo in stile logo altrove nell'app
  /// (in top bar ora c'è solo il simbolo, senza testo accanto).
  static TextStyle display({Color color = VexonColors.textPrimary}) => GoogleFonts.rajdhani(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
      );

  /// Titoli di sezione, header di dialoghi.
  static TextStyle heading({Color color = VexonColors.textPrimary, double fontSize = 17}) =>
      GoogleFonts.rajdhani(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  /// Titoli minori — nome del gioco su una card, voce di lista.
  static TextStyle title({Color color = VexonColors.textPrimary, double fontSize = 14}) =>
      GoogleFonts.rajdhani(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      );

  /// Testo corrente — menu, campi di ricerca, contenuto dei dialoghi.
  static TextStyle body({Color color = VexonColors.textPrimary, double fontSize = 14}) =>
      GoogleFonts.rajdhani(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      );

  /// Testo secondario — didascalie, sottotitoli, nome GPU/scheda.
  static TextStyle caption({Color color = VexonColors.textSecondary, double fontSize = 11.5}) =>
      GoogleFonts.rajdhani(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  // ---------------------------------------------------------------------
  // VT323 — readout numerici stile HUD
  // ---------------------------------------------------------------------

  /// Valore numerico in evidenza — es. il numero al centro dei gauge
  /// circolari (CPU/GPU/RAM %).
  static TextStyle digitalLarge({Color color = VexonColors.textPrimary, double fontSize = 28}) =>
      GoogleFonts.vt323(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1,
      );

  /// Readout numerico medio — orologio, temperature, contatori.
  static TextStyle digital({Color color = VexonColors.textSecondary, double fontSize = 20}) =>
      GoogleFonts.vt323(
        color: color,
        fontSize: fontSize,
        letterSpacing: 1.2,
        height: 1,
      );

  /// Readout numerico piccolo — uptime, session id, dettagli minori.
  static TextStyle digitalSmall({Color color = VexonColors.textDisabled, double fontSize = 13}) =>
      GoogleFonts.vt323(
        color: color,
        fontSize: fontSize,
        letterSpacing: 0.8,
      );
}
