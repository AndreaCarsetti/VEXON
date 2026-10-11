import 'package:window_manager/window_manager.dart';
import 'window_state.dart';

/// Gestisce la transizione da modalità kiosk (fullscreen) a finestra
/// normale di Windows.
///
/// NON usa più `always-on-top`: VEXON resta a schermo intero ma si
/// comporta come una qualunque finestra normale rispetto al focus — se
/// apri un gioco, il selettore file, Esplora file, ecc., quelle finestre
/// possono comparire davanti senza che VEXON debba fare nulla di
/// speciale per farsi da parte (prima serviva togliere manualmente
/// l'always-on-top proprio per questo).
///
/// LIMITAZIONE NOTA: window_manager gestisce il fullscreen in modo
/// cross-platform, ma NON nasconde/mostra la taskbar di Windows né
/// blocca Alt-Tab/tasto Windows — quello richiede codice nativo Win32
/// aggiuntivo in windows/runner/win32_window.cpp (non incluso in questo
/// scaffold). Per ora "modalità kiosk" significa: finestra fullscreen
/// borderless, senza vero blocco di sistema.
class KioskService {
  static Future<void> exitKiosk() async {
    await windowManager.setFullScreen(false);
    await windowManager.setResizable(true);
    await windowManager.center();
    WindowState.isKiosk.value = false;
  }

  static Future<void> enterKiosk() async {
    await windowManager.setFullScreen(true);
    WindowState.isKiosk.value = true;
  }

  /// Storicamente toglieva temporaneamente l'always-on-top per lasciare
  /// comparire finestre esterne (selettore file, Esplora file...). Non
  /// serve più: VEXON non è mai always-on-top, quindi qui si esegue
  /// semplicemente [action] — il metodo resta per non dover toccare tutti
  /// i punti che lo chiamano.
  static Future<T> withoutAlwaysOnTop<T>(Future<T> Function() action) {
    return action();
  }
}
