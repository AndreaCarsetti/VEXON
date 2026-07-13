import 'package:flutter/foundation.dart';

/// Stato condiviso: true = modalità kiosk (fullscreen, always-on-top),
/// false = finestra normale (dopo uscita con ESC).
///
/// Usato per decidere quando mostrare la barra dei controlli finestra
/// personalizzata (riduci a icona / schermo intero / chiudi) — non serve
/// in modalità kiosk, ma è necessaria in modalità finestra dato che il
/// titleBarStyle è impostato su `hidden` (niente controlli nativi Windows).
class WindowState {
  WindowState._();
  static final ValueNotifier<bool> isKiosk = ValueNotifier<bool>(true);
}
