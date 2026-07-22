import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';
import 'win32_registry_utils.dart';

/// Una voce letta dal registro "Programmi e funzionalità" di Windows
/// (`...\CurrentVersion\Uninstall\...`).
class UninstallEntry {
  final String displayName;
  final String? installLocation;
  final String? displayIcon;
  final String? publisher;

  const UninstallEntry({
    required this.displayName,
    this.installLocation,
    this.displayIcon,
    this.publisher,
  });
}

/// Le chiavi Uninstall standard di Windows — ogni programma "regolare"
/// (installato con un vero setup, non portable) ne scrive una per
/// comparire in "Programmi e funzionalità" / "App installate". La maggior
/// parte dei launcher di terze parti (Battle.net, EA App, Ubisoft Connect,
/// GOG Galaxy) registra qui i propri giochi proprio per questo motivo,
/// anche se il "vero" catalogo interno del launcher è altrove e spesso in
/// un formato proprietario molto più complesso da leggere.
///
/// Si controllano sia il ramo a 64 bit che quello Wow6432Node (dove
/// finiscono le entry scritte da installer a 32 bit, ancora comuni), e sia
/// HKEY_LOCAL_MACHINE (installazioni per tutti gli utenti, il caso più
/// frequente) che HKEY_CURRENT_USER (installazioni per-utente).
const _uninstallKeyPaths = [
  r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  r'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
];

/// Scansiona le chiavi Uninstall del registro e ritorna le voci il cui
/// `Publisher` contiene (case-insensitive) una delle stringhe in
/// [publisherMatches]. Non lancia mai eccezioni verso il chiamante: se una
/// chiave non esiste o l'accesso viene negato, viene semplicemente
/// ignorata — utile perché ad esempio HKEY_CURRENT_USER\...\Uninstall
/// spesso non esiste affatto se non ci sono installazioni per-utente.
List<UninstallEntry> scanUninstallEntries(List<String> publisherMatches) {
  if (!Platform.isWindows) return [];

  final matches = publisherMatches.map((m) => m.toLowerCase()).toList();
  final results = <UninstallEntry>[];
  final seenDisplayNames = <String>{};

  for (final hive in [HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER]) {
    for (final keyPath in _uninstallKeyPaths) {
      final hKey = Win32RegistryUtils.openKey(hive, keyPath);
      if (hKey == null) continue; // chiave assente su questa macchina

      try {
        for (final subkeyName in Win32RegistryUtils.enumSubkeyNames(hKey)) {
          final subkeyPath = '$keyPath\\$subkeyName';
          final hSubkey = Win32RegistryUtils.openKey(hive, subkeyPath);
          if (hSubkey == null) continue;

          try {
            final publisher = Win32RegistryUtils.getStringValue(hSubkey, 'Publisher');
            if (publisher == null) continue;
            if (!matches.any((m) => publisher.toLowerCase().contains(m))) continue;

            final displayName = Win32RegistryUtils.getStringValue(hSubkey, 'DisplayName');
            if (displayName == null || displayName.trim().isEmpty) continue;

            // Alcuni publisher registrano più voci correlate (runtime,
            // DLC, componenti separati) con lo stesso DisplayName del
            // gioco principale — la prima trovata vince, le altre sono
            // quasi sempre rumore.
            if (!seenDisplayNames.add(displayName.toLowerCase())) continue;

            results.add(UninstallEntry(
              displayName: displayName,
              installLocation: Win32RegistryUtils.getStringValue(hSubkey, 'InstallLocation'),
              displayIcon: Win32RegistryUtils.getStringValue(hSubkey, 'DisplayIcon'),
              publisher: publisher,
            ));
          } finally {
            Win32RegistryUtils.closeKey(hSubkey);
          }
        }
      } finally {
        Win32RegistryUtils.closeKey(hKey);
      }
    }
  }

  return results;
}

/// Prova a ricavare un eseguibile utilizzabile da una [UninstallEntry].
/// `DisplayIcon` punta spesso proprio all'exe del gioco (a volte con un
/// suffisso ",0" per l'indice dell'icona, da rimuovere), ma non è garantito
/// — in mancanza, si cerca il .exe più grande direttamente dentro
/// `InstallLocation` (euristica: il file più pesante nella cartella
/// d'installazione è quasi sempre l'eseguibile principale del gioco,
/// mentre launcher/updater satellite sono in genere molto più leggeri).
String? resolveExecutable(UninstallEntry entry) {
  final icon = entry.displayIcon;
  if (icon != null) {
    final cleanPath = icon.split(',').first.trim();
    if (cleanPath.toLowerCase().endsWith('.exe') && File(cleanPath).existsSync()) {
      return cleanPath;
    }
  }

  final installLocation = entry.installLocation;
  if (installLocation == null || installLocation.trim().isEmpty) return null;

  final dir = Directory(installLocation);
  if (!dir.existsSync()) return null;

  File? largest;
  try {
    for (final entity in dir.listSync(recursive: false)) {
      if (entity is! File) continue;
      if (p.extension(entity.path).toLowerCase() != '.exe') continue;
      if (largest == null || entity.lengthSync() > largest.lengthSync()) {
        largest = entity;
      }
    }
  } catch (_) {
    return null;
  }

  return largest?.path;
}
