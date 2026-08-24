import 'dart:async';
import 'dart:io';
import 'native_hardware_reader.dart';

class WifiStatus {
  final String ssid;
  final int signalPercent;
  const WifiStatus({required this.ssid, required this.signalPercent});
}

class VolumeStatus {
  final int percent;
  final bool muted;
  const VolumeStatus({required this.percent, required this.muted});
}

class BatteryStatus {
  final int percent;
  final bool charging;
  const BatteryStatus({required this.percent, required this.charging});
}

class DiskInfo {
  final String drive;
  final double freeGb;
  final double totalGb;
  const DiskInfo({required this.drive, required this.freeGb, required this.totalGb});

  double get usedGb => totalGb - freeGb;
}

class NetworkStatus {
  final double downKBps;
  final double upKBps;
  const NetworkStatus({required this.downKBps, required this.upKBps});
}

class SecurityStatus {
  final bool realTimeProtection;
  final int? signatureAgeDays;
  const SecurityStatus({required this.realTimeProtection, this.signatureAgeDays});
}

class SystemTrayStats {
  final WifiStatus? wifi;
  final VolumeStatus? volume;
  final BatteryStatus? battery;
  final List<DiskInfo> disks;
  final NetworkStatus? network;
  final String? gpuName;
  final double? gpuUsagePercent;
  final SecurityStatus? security;

  const SystemTrayStats({
    this.wifi,
    this.volume,
    this.battery,
    this.disks = const [],
    this.network,
    this.gpuName,
    this.gpuUsagePercent,
    this.security,
  });
}

/// Legge lo stato di WiFi, volume, batteria, disco, rete e sicurezza per
/// la barra di sistema dell'HUD. Ogni lettura è indipendente e "best
/// effort": se una fallisce (nessun WiFi, PC desktop senza batteria,
/// ecc.) ritorna semplicemente `null` per quella voce — l'assenza di un
/// dato non deve mai bloccare o rompere le altre.
///
/// Due velocità di aggiornamento diverse, per non lanciare processi
/// `netsh`/`powershell` più spesso del necessario:
/// - **veloce (4s)**: WiFi, volume, rete — cambiano spesso.
/// - **lenta (30s)**: spazio disco, stato sicurezza — cambiano di rado, e
///   la lettura sicurezza in particolare è un po' più pesante.
/// - **una sola volta**: nome GPU — è un fatto statico dell'hardware.
class SystemTrayService {
  final _controller = StreamController<SystemTrayStats>.broadcast();
  final _reader = NativeHardwareReader();
  Timer? _fastTimer;
  Timer? _slowTimer;

  WifiStatus? _lastWifi;
  VolumeStatus? _lastVolume;
  NetworkStatus? _lastNetwork;
  double? _lastGpuUsage;
  List<DiskInfo> _lastDisks = [];
  SecurityStatus? _lastSecurity;
  String? _gpuName;

  Stream<SystemTrayStats> get statsStream => _controller.stream;

  SystemTrayService() {
    _loadGpuNameOnce();
    _fastTimer = Timer.periodic(const Duration(seconds: 4), (_) => _sampleFast());
    _slowTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sampleSlow());
    _sampleFast();
    _sampleSlow();
  }

  void dispose() {
    _fastTimer?.cancel();
    _slowTimer?.cancel();
    _controller.close();
  }

  void _emit() {
    _controller.add(SystemTrayStats(
      wifi: _lastWifi,
      volume: _lastVolume,
      battery: _readBattery(),
      disks: _lastDisks,
      network: _lastNetwork,
      gpuName: _gpuName,
      gpuUsagePercent: _lastGpuUsage,
      security: _lastSecurity,
    ));
  }

  Future<void> _sampleFast() async {
    final results = await Future.wait([_readWifi(), _readVolume(), _readNetwork(), _readGpuUsage()]);
    _lastWifi = results[0] as WifiStatus?;
    _lastVolume = results[1] as VolumeStatus?;
    _lastNetwork = results[2] as NetworkStatus?;
    _lastGpuUsage = results[3] as double?;
    _emit();
  }

  Future<void> _sampleSlow() async {
    final results = await Future.wait([_readDiskSpace(), _readSecurity()]);
    _lastDisks = results[0] as List<DiskInfo>;
    _lastSecurity = results[1] as SecurityStatus?;
    _emit();
  }

  Future<void> _loadGpuNameOnce() async {
    _gpuName = await _readGpuName();
    _emit();
  }

  BatteryStatus? _readBattery() {
    final status = _reader.readBatteryStatus();
    if (status == null) return null;
    return BatteryStatus(percent: status.percent, charging: status.charging);
  }

  /// Nome della scheda video tramite WMI. Sui PC con GPU integrata +
  /// dedicata (il caso più comune per un gaming PC) sceglie quella con più
  /// VRAM riportata (in genere la dedicata), escludendo adattatori
  /// generici/virtuali che non sono una vera scheda video.
  Future<String?> _readGpuName() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _gpuScript],
      ).timeout(const Duration(seconds: 8));
      if (result.exitCode != 0) return null;

      final name = result.stdout.toString().trim();
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  static const _gpuScript = r'''
Get-CimInstance -ClassName Win32_VideoController |
  Where-Object { $_.Name -notlike "*Basic*" -and $_.Name -notlike "*Remote*" } |
  Sort-Object -Property AdapterRAM -Descending |
  Select-Object -First 1 -ExpandProperty Name
''';

  /// Uso GPU tramite il contatore prestazionale "GPU Engine" integrato in
  /// Windows (10 versione 1803+) — lo stesso che usa Task Manager per la
  /// sua scheda GPU. Funziona con qualunque scheda video (NVIDIA/AMD/
  /// Intel) perché legge le statistiche dello scheduler GPU del sistema
  /// operativo stesso, non un'API specifica del produttore — a differenza
  /// della temperatura, che invece richiederebbe SDK proprietari (NVML
  /// per NVIDIA, ADL per AMD) non inclusi qui, quindi resta "N/D".
  ///
  /// Approssimazione onesta: prende il valore più alto tra le istanze del
  /// motore 3D (quella su cui si basa più tipicamente il "%" mostrato per
  /// la GPU) — può non corrispondere esattamente al numero di Task
  /// Manager in scenari con più processi che usano la GPU insieme, ma è
  /// un dato reale, non inventato.
  Future<double?> _readGpuUsage() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _gpuUsageScript],
      ).timeout(const Duration(seconds: 6));
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return null;

      final value = double.tryParse(output);
      return value?.clamp(0, 100);
    } catch (_) {
      return null;
    }
  }

  static const _gpuUsageScript = r'''
function Get-Gpu3DUsage {
  # Tentativo 1: classe WMI dedicata — nomi di classe/proprietà SEMPRE in
  # inglese indipendentemente dalla lingua di Windows, quindi nessun
  # rischio di traduzione (lo stesso motivo per cui disco/sicurezza/nome
  # GPU hanno sempre funzionato qui).
  try {
    $samples = Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
      Where-Object { $_.Name -like '*engtype_3d*' }
    $max = ($samples | Measure-Object -Property UtilizationPercentage -Maximum).Maximum
    if ($null -ne $max) { return $max }
  } catch {}

  # Tentativo 2 (riserva, se la classe WMI non esiste su questo Windows):
  # stessa idea ma via Get-Counter, i cui nomi SONO tradotti in base alla
  # lingua di sistema — si cerca quindi l'ID numerico del contatore nella
  # tabella inglese del registro invece di usare il nome, che è fisso
  # indipendentemente dalla lingua.
  try {
    $englishCounters = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\009' -Name Counter).Counter
    $gpuEngineId = $null
    $utilId = $null
    for ($i = 0; $i -lt $englishCounters.Count; $i += 2) {
      if ($englishCounters[$i + 1] -eq 'GPU Engine') { $gpuEngineId = $englishCounters[$i] }
      if ($englishCounters[$i + 1] -eq 'Utilization Percentage') { $utilId = $englishCounters[$i] }
    }
    if ($gpuEngineId -and $utilId) {
      $path = "\$gpuEngineId(*)\$utilId"
      $samples2 = (Get-Counter -Counter $path -ErrorAction Stop).CounterSamples |
        Where-Object { $_.InstanceName -like '*engtype_3d*' }
      $max2 = ($samples2 | Measure-Object -Property CookedValue -Maximum).Maximum
      if ($null -ne $max2) { return $max2 }
    }
  } catch {}

  return $null
}

$result = Get-Gpu3DUsage
if ($null -eq $result) {
  Write-Output ""
} else {
  Write-Output $result
}
''';

  /// Stato di Windows Defender (protezione in tempo reale attiva/no, età
  /// delle definizioni) tramite il cmdlet `Get-MpComputerStatus`,
  /// integrato in Windows. Riflette SOLO Windows Defender: se hai un
  /// antivirus di terze parti, Windows spesso disattiva automaticamente
  /// Defender in suo favore — "disattivata" qui non significa
  /// necessariamente "PC sprotetto", solo che Defender specificamente non
  /// è la protezione attiva in questo momento.
  Future<SecurityStatus?> _readSecurity() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _securityScript],
      ).timeout(const Duration(seconds: 8));
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString().trim();
      if (output == 'ERROR' || output.isEmpty) return null;

      final parts = output.split('|');
      if (parts.length != 2) return null;

      final enabled = parts[0].trim().toLowerCase() == 'true';
      final age = int.tryParse(parts[1].trim());

      return SecurityStatus(realTimeProtection: enabled, signatureAgeDays: age);
    } catch (_) {
      return null;
    }
  }

  static const _securityScript = r'''
try {
  $s = Get-MpComputerStatus -ErrorAction Stop
  Write-Output "$($s.RealTimeProtectionEnabled)|$($s.AntivirusSignatureAge)"
} catch {
  Write-Output "ERROR"
}
''';

  /// Legge SSID e intensità del segnale tramite `netsh wlan show
  /// interfaces` — comando integrato in Windows dai tempi di Vista,
  /// nessun tool esterno richiesto.
  ///
  /// L'output di netsh è TRADOTTO nella lingua di sistema (in italiano
  /// dice "Stato"/"Segnale" invece di "State"/"Signal"), quindi il parsing
  /// non si basa su quelle etichette: cerca invece "SSID" (acronimo
  /// tecnico, non tradotto in nessuna lingua) e un numero seguito da "%"
  /// per il segnale — entrambi stabili indipendentemente dalla lingua di
  /// Windows.
  Future<WifiStatus?> _readWifi() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('netsh', ['wlan', 'show', 'interfaces'])
          .timeout(const Duration(seconds: 5));
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final lines = output.split('\n');

      String? ssid;
      int? signal;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        // "BSSID" contiene anch'esso la sottostringa "SSID" — va escluso
        // esplicitamente per non confonderlo con la riga SSID vera.
        if (line.startsWith('SSID') && !line.startsWith('BSSID')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            ssid = parts.sublist(1).join(':').trim();
          }
        }
        final signalMatch = RegExp(r'(\d{1,3})\s*%').firstMatch(line);
        if (signalMatch != null && line.toLowerCase().contains(RegExp(r'segnal|signal'))) {
          signal = int.tryParse(signalMatch.group(1)!);
        }
      }

      if (ssid == null || ssid.isEmpty) return null;
      return WifiStatus(ssid: ssid, signalPercent: signal ?? 0);
    } catch (_) {
      return null;
    }
  }

  /// Volume corrente e stato muto, tramite le API Core Audio di Windows
  /// (IAudioEndpointVolume) via un piccolo helper COM invocato da
  /// PowerShell — tecnica standard, nessun tool di terze parti richiesto,
  /// funziona su qualunque Windows moderno senza permessi speciali.
  Future<VolumeStatus?> _readVolume() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _audioScript(_getVolumeAndMute)],
      ).timeout(const Duration(seconds: 8));

      if (result.exitCode != 0) return null;
      final output = result.stdout.toString().trim();
      final parts = output.split('|');
      if (parts.length != 2) return null;

      final level = double.tryParse(parts[0]);
      final muted = parts[1].trim().toLowerCase() == 'true';
      if (level == null) return null;

      return VolumeStatus(percent: (level * 100).round().clamp(0, 100), muted: muted);
    } catch (_) {
      return null;
    }
  }

  /// Attiva/disattiva il muto — azione diretta dell'utente (click
  /// sull'icona volume), non fa parte del campionamento periodico.
  Future<void> toggleMute() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _audioScript(_toggleMute)],
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // silenzioso: se fallisce, l'icona semplicemente non cambia stato
      // al prossimo campionamento — nessun crash da mostrare all'utente
      // per un'azione così secondaria.
    }
  }

  /// Spazio disco per unità fisse (esclude CD/DVD e drive di rete),
  /// tramite WMI. Preferito a una chiamata FFI diretta a
  /// GetDiskFreeSpaceEx: quella funzione ha una firma che cambia tra le
  /// versioni del pacchetto win32 (già incontrato lo stesso problema col
  /// registro), mentre WMI è stabile da vent'anni ed è quello che usano
  /// anche Task Manager e Esplora file internamente.
  Future<List<DiskInfo>> _readDiskSpace() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _diskScript],
      ).timeout(const Duration(seconds: 8));
      if (result.exitCode != 0) return [];

      final disks = <DiskInfo>[];
      const bytesPerGb = 1024 * 1024 * 1024;
      for (final rawLine in result.stdout.toString().split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final parts = line.split('|');
        if (parts.length != 3) continue;

        final freeBytes = double.tryParse(parts[1]);
        final totalBytes = double.tryParse(parts[2]);
        if (freeBytes == null || totalBytes == null || totalBytes <= 0) continue;

        disks.add(DiskInfo(
          drive: parts[0],
          freeGb: freeBytes / bytesPerGb,
          totalGb: totalBytes / bytesPerGb,
        ));
      }
      return disks;
    } catch (_) {
      return [];
    }
  }

  static const _diskScript = r'''
Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  Write-Output "$($_.DeviceID)|$($_.FreeSpace)|$($_.Size)"
}
''';

  /// Velocità di rete istantanea (download/upload), tramite i contatori
  /// prestazionali di Windows — già calcolati "al secondo" dal sistema,
  /// non serve campionare due volte e fare la differenza manualmente.
  /// Esclude interfacce virtuali/tunnel (loopback, isatap, Teredo) che
  /// altrimenti gonfierebbero il numero con traffico che non è vero
  /// traffico di rete reale.
  Future<NetworkStatus?> _readNetwork() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _networkScript],
      ).timeout(const Duration(seconds: 8));
      if (result.exitCode != 0) return null;

      final parts = result.stdout.toString().trim().split('|');
      if (parts.length != 2) return null;

      final downBytes = double.tryParse(parts[0]);
      final upBytes = double.tryParse(parts[1]);
      if (downBytes == null || upBytes == null) return null;

      return NetworkStatus(downKBps: downBytes / 1024, upKBps: upBytes / 1024);
    } catch (_) {
      return null;
    }
  }

  static const _networkScript = r'''
$ErrorActionPreference = "Stop"
try {
  # Stesso problema di localizzazione del contatore GPU: "Network
  # Interface"/"Bytes Received/sec"/"Bytes Sent/sec" sono nomi tradotti
  # in base alla lingua di Windows — si cercano i loro ID numerici nella
  # tabella inglese del registro, indipendenti dalla lingua.
  $englishCounters = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib\009' -Name Counter).Counter

  $nicId = $null
  $recvId = $null
  $sentId = $null
  for ($i = 0; $i -lt $englishCounters.Count; $i += 2) {
    if ($englishCounters[$i + 1] -eq 'Network Interface') { $nicId = $englishCounters[$i] }
    if ($englishCounters[$i + 1] -eq 'Bytes Received/sec') { $recvId = $englishCounters[$i] }
    if ($englishCounters[$i + 1] -eq 'Bytes Sent/sec') { $sentId = $englishCounters[$i] }
  }

  if (-not $nicId -or -not $recvId -or -not $sentId) {
    Write-Output "0|0"
  } else {
    $down = (Get-Counter -Counter "\$nicId(*)\$recvId").CounterSamples |
      Where-Object { $_.InstanceName -notmatch 'isatap|loopback|teredo' } |
      Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum
    $up = (Get-Counter -Counter "\$nicId(*)\$sentId").CounterSamples |
      Where-Object { $_.InstanceName -notmatch 'isatap|loopback|teredo' } |
      Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum
    Write-Output "$down|$up"
  }
} catch {
  Write-Output "0|0"
}
''';

  static const _typeDefinition = r'''
using System;
using System.Runtime.InteropServices;

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
  int NotImpl1();
  int NotImpl2();
  int NotImpl3();
  int NotImpl4();
  int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
  int NotImpl5();
  int GetMasterVolumeLevelScalar(out float pfLevel);
  int NotImpl6();
  int NotImpl7();
  int NotImpl8();
  int NotImpl9();
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
  int GetMute(out bool pbMute);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
  int Activate(ref Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
  int NotImpl1();
  int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

public class VexonAudio {
  static IAudioEndpointVolume Vol() {
    var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
    IMMDevice dev = null;
    Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(0, 1, out dev));
    var epvid = typeof(IAudioEndpointVolume).GUID;
    IAudioEndpointVolume epv = null;
    Marshal.ThrowExceptionForHR(dev.Activate(ref epvid, 23, 0, out epv));
    return epv;
  }

  public static string GetVolumeAndMute() {
    float level;
    bool mute;
    Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out level));
    Marshal.ThrowExceptionForHR(Vol().GetMute(out mute));
    return level.ToString(System.Globalization.CultureInfo.InvariantCulture) + "|" + mute;
  }

  public static void ToggleMute() {
    bool mute;
    Marshal.ThrowExceptionForHR(Vol().GetMute(out mute));
    Marshal.ThrowExceptionForHR(Vol().SetMute(!mute, Guid.Empty));
  }
}
''';

  static const _getVolumeAndMute = '[VexonAudio]::GetVolumeAndMute()';
  static const _toggleMute = '[VexonAudio]::ToggleMute()';

  String _audioScript(String call) {
    return 'Add-Type -TypeDefinition @"\n$_typeDefinition\n"@\n$call';
  }
}
