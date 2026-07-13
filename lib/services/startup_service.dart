import 'package:launch_at_startup/launch_at_startup.dart';
import 'dart:io';

/// Registra VEXON per l'avvio automatico insieme a Windows.
///
/// Sotto il cofano, il pacchetto `launch_at_startup` crea una entry nel
/// registro di Windows (HKCU\...\Run) che punta all'eseguibile dell'app —
/// è lo stesso meccanismo standard usato da app come Steam o Discord per
/// "avvia con Windows", non richiede privilegi da amministratore.
///
/// NOTA IMPORTANTE: `Platform.resolvedExecutable` in modalità debug punta
/// al processo `dart.exe`/`flutter_tester`, NON al vero eseguibile
/// dell'app. L'avvio automatico va quindi testato sulla build di rilascio
/// (`flutter build windows`), non durante `flutter run`.
class StartupService {
  static Future<void> initialize() async {
    launchAtStartup.setup(
      appName: 'VEXON',
      appPath: Platform.resolvedExecutable,
    );
  }

  static Future<void> enable() => launchAtStartup.enable();
  static Future<void> disable() => launchAtStartup.disable();
  static Future<bool> isEnabled() => launchAtStartup.isEnabled();
}
