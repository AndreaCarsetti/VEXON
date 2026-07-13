import 'dart:io';
import 'package:path/path.dart' as p;

/// Avvia (e ferma) il companion service .NET come processo separato in
/// background, così l'utente non deve lanciarlo a mano.
///
/// Cerca `vexon_hardware_service.exe` nella stessa cartella dell'eseguibile
/// principale di VEXON — è lì che deve finire durante il packaging
/// dell'installer (vedi installer/vexon_installer.iss: va aggiunta una riga
/// [Files] che copia anche questo eseguibile pubblicato).
class HardwareCompanionLauncher {
  static Process? _process;

  static Future<void> start() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final companionPath = p.join(exeDir, 'vexon_hardware_service.exe');

    if (!await File(companionPath).exists()) {
      // Normale durante lo sviluppo (flutter run) finché non si pubblica
      // anche il companion e lo si copia accanto all'eseguibile principale.
      // HardwareMonitorService.companion() ricade comunque sui dati mock
      // se non trova nessun servizio in ascolto sulla porta prevista.
      return;
    }

    try {
      // NOTA: il companion richiede privilegi di amministratore (vedi
      // companion_service/README.md). Avviato così, da un processo non
      // elevato, Windows mostrerà comunque il prompt UAC per il companion
      // — è un comportamento nativo di Windows quando un processo prova ad
      // avviarne un altro con `requireAdministrator` nel manifest.
      _process = await Process.start(
        companionPath,
        [],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      // Se l'avvio fallisce (utente nega l'UAC, permessi, ecc.) l'app
      // principale continua comunque a funzionare con i dati mock.
    }
  }

  static void stop() {
    // In modalità detached il processo non è collegato al ciclo di vita
    // dell'app Dart — se vuoi che il companion si chiuda insieme a VEXON,
    // qui va aggiunta la logica per terminarlo esplicitamente (es. tramite
    // il suo PID, o un endpoint HTTP di shutdown esposto dal companion
    // stesso). Non ancora implementato in questo scaffold.
  }
}
