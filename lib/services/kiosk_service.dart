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
}
