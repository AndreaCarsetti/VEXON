import 'dart:io';

/// Attiva/disattiva la modalità "Game Boost".
///
/// Cosa fa DAVVERO (e cosa NON fa, di proposito):
///
/// 1. **Cambia il piano di alimentazione** su "Prestazioni elevate"
///    (GUID nativo di Windows, nessuna creazione di piani custom) e lo
///    ripristina esattamente a quello di prima alla disattivazione.
/// 2. **Abbassa la priorità** (non chiude, non sospende) di una lista
///    ristretta e esplicita di app di sincronizzazione/background note
///    (vedi [_deprioritizeList]) — mai processi di sistema, mai app di
///    comunicazione che potresti voler usare durante il gioco (browser,
///    client email...), escluse di proposito.
///
/// NON fa (di proposito, per sicurezza):
/// - non chiude né sospende nessun processo (rischio di perdita dati)
/// - non tocca le notifiche di Windows (Focus Assist) — richiederebbe
///   toccare API/registro non ufficialmente documentati, rimandato
/// - non modifica impostazioni GPU/overclock
///
/// Se in futuro vuoi ampliare la whitelist, aggiungi solo nomi di processi
/// che conosci con certezza essere sicuri da deprioritizzare — mai un
/// elenco generico "tutto tranne il gioco".
class GameBoostService {
  static const _highPerformanceGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';

  /// Whitelist conservativa: solo processi di sincronizzazione/aggiornamento
  /// ben noti. Nomi SENZA ".exe" (così li vuole PowerShell `Get-Process`).
  static const _deprioritizeList = [
    'OneDrive',
    'Dropbox',
    'GoogleDriveFS',
    'Adobe Desktop Service',
  ];

  static String? _previousPowerSchemeGuid;
  static bool _isActive = false;

  static Future<void> enable() async {
    if (_isActive) return;
    await _switchToHighPerformance();
    await _setPriorityForList('BelowNormal');
    _isActive = true;
  }

  static Future<void> disable() async {
    if (!_isActive) return;
    await _restorePreviousPowerPlan();
    await _setPriorityForList('Normal');
    _isActive = false;
  }

  static Future<void> _switchToHighPerformance() async {
    try {
      // Salva il piano attivo attuale per poterlo ripristinare dopo.
      final current = await Process.run('powercfg', ['/getactivescheme']);
      final match = RegExp(r'([0-9a-fA-F]{8}-[0-9a-fA-F-]{27})')
          .firstMatch(current.stdout.toString());
      _previousPowerSchemeGuid = match?.group(1);

      await Process.run('powercfg', ['/setactive', _highPerformanceGuid]);
    } catch (_) {
      // Se powercfg non è disponibile o fallisce per qualunque motivo,
      // l'app continua a funzionare normalmente, semplicemente senza il
      // boost sul piano di alimentazione.
    }
  }

  static Future<void> _restorePreviousPowerPlan() async {
    final guid = _previousPowerSchemeGuid;
    if (guid == null) return;
    try {
      await Process.run('powercfg', ['/setactive', guid]);
    } catch (_) {}
    _previousPowerSchemeGuid = null;
  }

  static Future<void> _setPriorityForList(String priorityClass) async {
    final quotedNames = _deprioritizeList.map((n) => '"$n"').join(',');
    final script = 'Get-Process -Name $quotedNames -ErrorAction SilentlyContinue | '
        "ForEach-Object { \$_.PriorityClass = '$priorityClass' }";
    try {
      await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      );
    } catch (_) {
      // Se PowerShell non è raggiungibile o un processo nella lista non
      // esiste più, non è un errore critico: il piano di alimentazione
      // (la parte con più impatto) è comunque già stato applicato.
    }
  }
}
