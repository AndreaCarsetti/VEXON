import 'package:window_manager/window_manager.dart';
import 'window_state.dart';

/// Gestisce la transizione da modalità kiosk (fullscreen, always-on-top)
/// a finestra normale di Windows.
///
/// LIMITAZIONE NOTA: window_manager gestisce fullscreen/always-on-top in
/// modo cross-platform, ma NON nasconde/mostra la taskbar di Windows né
/// blocca Alt-Tab/tasto Windows — quello richiede codice nativo Win32
/// aggiuntivo in windows/runner/win32_window.cpp (non incluso in questo
/// scaffold). Per ora "modalità kiosk" significa: finestra fullscreen
/// borderless sempre in primo piano, senza vero blocco di sistema.
class KioskService {
  static Future<void> exitKiosk() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);
    await windowManager.setResizable(true);
    await windowManager.center();
    WindowState.isKiosk.value = false;
  }

  static Future<void> enterKiosk() async {
    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);
    WindowState.isKiosk.value = true;
  }

  /// Esegue [action] dopo aver tolto temporaneamente l'always-on-top (se
  /// attivo), ripristinandolo subito dopo — non tocca fullscreen, solo
  /// l'always-on-top.
  ///
  /// PERCHÉ SERVE: qualsiasi finestra nativa esterna a VEXON (es. il
  /// selettore file di Windows aperto da "Sfoglia…") viene aperta come
  /// finestra separata, non always-on-top essa stessa — quindi, con VEXON
  /// sempre in primo piano, ci finirebbe dietro: invisibile e non
  /// cliccabile, sembra che "non si apra". Va usato attorno a qualunque
  /// azione che possa far comparire una finestra esterna.
  static Future<T> withoutAlwaysOnTop<T>(Future<T> Function() action) async {
    final wasKiosk = WindowState.isKiosk.value;
    if (wasKiosk) {
      await windowManager.setAlwaysOnTop(false);
    }
    try {
      return await action();
    } finally {
      // Ripristina solo se eravamo effettivamente in kiosk prima — se nel
      // frattempo l'utente è già uscito dalla modalità kiosk (es. ESC),
      // non ha senso rimetterla noi.
      if (wasKiosk && WindowState.isKiosk.value) {
        await windowManager.setAlwaysOnTop(true);
      }
    }
  }
}
