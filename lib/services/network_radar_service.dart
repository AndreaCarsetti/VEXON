import 'dart:async';
import 'dart:io';

class NetworkDevice {
  final String ip;
  const NetworkDevice({required this.ip});
}

/// Elenca i dispositivi visti di recente sulla rete locale, leggendo la
/// cache ARP/vicinato di Windows (`Get-NetNeighbor`) — NON è una vera
/// scansione attiva di tutta la sottorete (che richiederebbe pingare
/// decine di indirizzi, più lento e più invasivo): mostra solo i
/// dispositivi con cui il PC ha già comunicato di recente. Onesto ma
/// limitato — se un dispositivo è sulla rete ma il PC non gli ha ancora
/// "parlato", non comparirà finché non lo fa.
///
/// Aggiornamento ogni 30 secondi: la topologia della rete locale non
/// cambia spesso, non serve interrogarla più frequentemente.
class NetworkRadarService {
  final _controller = StreamController<List<NetworkDevice>>.broadcast();
  Timer? _timer;

  Stream<List<NetworkDevice>> get devicesStream => _controller.stream;

  NetworkRadarService() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _scan());
    _scan();
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  Future<void> _scan() async {
    _controller.add(await _readDevices());
  }

  Future<List<NetworkDevice>> _readDevices() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', _script],
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) return [];

      final ips = result.stdout
          .toString()
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet() // rimuove duplicati (stesso IP con più voci di stato)
          .toList();

      return ips.map((ip) => NetworkDevice(ip: ip)).toList();
    } catch (_) {
      return [];
    }
  }

  static const _script = r'''
Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object {
    $_.State -in @('Reachable','Stale','Permanent') -and
    $_.IPAddress -notlike '127.*' -and
    $_.IPAddress -notlike '169.254.*' -and
    $_.LinkLayerAddress -ne '00-00-00-00-00-00'
  } |
  Select-Object -ExpandProperty IPAddress -Unique
''';
}
