import 'dart:io';
import 'kiosk_service.dart';

/// Azioni di sistema rapide, pensate per la visione di VEXON come
/// sostituto del desktop di Windows — cose che normalmente si farebbero
/// dal menu Start.
///
/// Spegnimento/riavvio/sospensione usano `shutdown.exe` (integrato in
/// Windows, nessun privilegio speciale richiesto per l'utente corrente)
/// e `rundll32.exe powrprof.dll,SetSuspendState` per la sospensione
/// (tecnica standard da riga di comando, usata da anni). Sono azioni
/// distruttive — la conferma va chiesta nella UI PRIMA di chiamare questi
/// metodi, qui non c'è alcuna conferma.
///
/// Le scorciatoie (Esplora file, Impostazioni, Task Manager) aprono
/// finestre esterne a VEXON: passano tutte da
/// [KioskService.withoutAlwaysOnTop], altrimenti — come già capitato col
/// selettore file — finirebbero nascoste dietro la finestra sempre in
/// primo piano di VEXON.
class SystemActionsService {
  static Future<void> shutdown() async {
    if (!Platform.isWindows) return;
    await Process.run('shutdown', ['/s', '/t', '0']);
  }

  static Future<void> restart() async {
    if (!Platform.isWindows) return;
    await Process.run('shutdown', ['/r', '/t', '0']);
  }

  static Future<void> sleep() async {
    if (!Platform.isWindows) return;
    await Process.run('rundll32.exe', ['powrprof.dll,SetSuspendState', '0,1,0']);
  }

  static Future<void> openFileExplorer() {
    return KioskService.withoutAlwaysOnTop(() => Process.start('explorer.exe', []));
  }

  static Future<void> openSettings() {
    return KioskService.withoutAlwaysOnTop(() => Process.start('explorer.exe', ['ms-settings:']));
  }

  static Future<void> openTaskManager() {
    return KioskService.withoutAlwaysOnTop(() => Process.start('taskmgr.exe', []));
  }

}
