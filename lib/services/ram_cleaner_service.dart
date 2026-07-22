import 'dart:io';

/// Libera RAM "sgonfiando" il working set dei processi in esecuzione,
/// tramite l'API Windows `EmptyWorkingSet` (psapi.dll) — la stessa tecnica
/// usata da tool come CCleaner o Mem Reduct per l'ottimizzazione RAM.
///
/// Cosa fa DAVVERO (e cosa NON fa, di proposito), stesso approccio di
/// trasparenza già usato in [GameBoostService]:
///
/// 1. Per ogni processo a cui si ha accesso, chiede a Windows di scaricare
///    dalla RAM fisica le pagine di memoria attualmente inutilizzate. Se
///    servono di nuovo, Windows le ricarica automaticamente — l'effetto è
///    un calo immediato dell'uso di RAM riportato, non un modo per
///    "recuperare" RAM che un programma sta usando attivamente.
/// 2. NON chiude, non sospende, non termina nessun processo: tocca solo la
///    loro impronta in memoria, mai la loro esecuzione.
/// 3. I processi di sistema o di altri utenti spesso non sono accessibili
///    senza privilegi elevati — vengono saltati silenziosamente, non è un
///    errore.
///
/// Va preso per quello che è: un'ottimizzazione cosmetica e temporanea,
/// non un modo per aumentare le prestazioni in modo permanente.
class RamCleanerService {
  static const _script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class VexonMemTrim {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@
$trimmed = 0
Get-Process | ForEach-Object {
    try {
        if ([VexonMemTrim]::EmptyWorkingSet($_.Handle)) { $trimmed++ }
    } catch {}
}
[GC]::Collect()
Write-Output $trimmed
''';

  /// Esegue la pulizia. Ritorna quanti processi sono stati effettivamente
  /// "sgonfiati" — un numero indicativo, non una misura di quanta RAM sia
  /// stata liberata (quella si legge dal monitor hardware già presente
  /// nell'app, confrontando lo snapshot prima e dopo).
  static Future<int> clean() async {
    if (!Platform.isWindows) return 0;

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _script],
      ).timeout(const Duration(seconds: 20));

      return int.tryParse(result.stdout.toString().trim()) ?? 0;
    } catch (_) {
      // PowerShell irraggiungibile o script fallito: nessun crash, solo
      // nessun processo risulta "sgonfiato".
      return 0;
    }
  }
}
