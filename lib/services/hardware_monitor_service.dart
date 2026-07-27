import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'native_hardware_reader.dart';

/// Snapshot dei parametri hardware in un dato istante.
///
/// `cpuTempCelsius`, `gpuUsagePercent` e `gpuTempCelsius` sono nullable:
/// con la lettura nativa via FFI (`.native()`) questi dati NON sono
/// disponibili senza privilegi di amministratore e driver di sistema
/// aggiuntivi — meglio mostrare onestamente "N/D" che inventare un numero.
/// Con il companion service (`.companion()`) invece sono sempre presenti.
class HardwareStats {
  final double cpuUsagePercent;
  final double? cpuTempCelsius;
  final double? gpuUsagePercent;
  final double? gpuTempCelsius;
  final double ramUsedGb;
  final double ramTotalGb;

  // Dati statici dell'hardware (non cambiano durante l'esecuzione) — letti
  // una sola volta dal servizio e ripetuti identici in ogni campione.
  final String? cpuName;
  final int? logicalProcessorCount;

  const HardwareStats({
    required this.cpuUsagePercent,
    this.cpuTempCelsius,
    this.gpuUsagePercent,
    this.gpuTempCelsius,
    required this.ramUsedGb,
    required this.ramTotalGb,
    this.cpuName,
    this.logicalProcessorCount,
  });

  double get ramUsagePercent => (ramUsedGb / ramTotalGb) * 100;

  factory HardwareStats.fromJson(Map<String, dynamic> json) {
    return HardwareStats(
      cpuUsagePercent: (json['cpuUsagePercent'] as num).toDouble(),
      cpuTempCelsius: (json['cpuTempCelsius'] as num?)?.toDouble(),
      gpuUsagePercent: (json['gpuUsagePercent'] as num?)?.toDouble(),
      gpuTempCelsius: (json['gpuTempCelsius'] as num?)?.toDouble(),
      ramUsedGb: (json['ramUsedGb'] as num).toDouble(),
      ramTotalGb: (json['ramTotalGb'] as num).toDouble(),
      cpuName: json['cpuName'] as String?,
      logicalProcessorCount: (json['logicalProcessorCount'] as num?)?.toInt(),
    );
  }
}

/// Tre modi per ottenere i dati hardware:
/// - `.mock()` — dati finti, utile per sviluppare la UI
/// - `.native()` — **consigliata**, legge CPU e RAM reali direttamente da
///   Flutter via FFI (API Windows native), senza nessun servizio esterno
///   da installare/avviare. GPU e temperature restano `null` (mostrate
///   come "N/D" nell'HUD) perché richiedono accesso a basso livello non
///   ottenibile senza driver aggiuntivi — vedi
///   `lib/services/native_hardware_reader.dart`.
/// - `.companion()` — dati completi (incluse temperature e uso GPU), ma
///   richiede di compilare e avviare `companion_service/` (.NET, privilegi
///   amministratore). Utile se in futuro vuoi davvero le temperature.
abstract class HardwareMonitorService {
  Stream<HardwareStats> get statsStream;
  void dispose();

  factory HardwareMonitorService.mock() = _MockHardwareMonitorService;
  factory HardwareMonitorService.native() = _NativeHardwareMonitorService;
  factory HardwareMonitorService.companion({
    Uri? endpoint,
    Duration pollInterval,
  }) = _CompanionHardwareMonitorService;
}

class _MockHardwareMonitorService implements HardwareMonitorService {
  final _controller = StreamController<HardwareStats>.broadcast();
  Timer? _timer;
  final _rnd = Random();

  _MockHardwareMonitorService() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _controller.add(HardwareStats(
        cpuUsagePercent: 20 + _rnd.nextDouble() * 60,
        cpuTempCelsius: 45 + _rnd.nextDouble() * 25,
        gpuUsagePercent: 10 + _rnd.nextDouble() * 80,
        gpuTempCelsius: 50 + _rnd.nextDouble() * 30,
        ramUsedGb: 6 + _rnd.nextDouble() * 6,
        ramTotalGb: 16,
        cpuName: 'CPU Simulata X9 (dati mock)',
        logicalProcessorCount: 16,
      ));
    });
  }

  @override
  Stream<HardwareStats> get statsStream => _controller.stream;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

class _NativeHardwareMonitorService implements HardwareMonitorService {
  final _controller = StreamController<HardwareStats>.broadcast();
  final _reader = NativeHardwareReader();
  Timer? _timer;

  // Letti una volta sola all'avvio: sono fatti statici dell'hardware, non
  // ha senso rileggerli dal registro/da GetSystemInfo ogni secondo.
  late final String? _cpuName = _reader.readCpuName();
  late final int? _logicalProcessorCount = _reader.readLogicalProcessorCount();

  _NativeHardwareMonitorService() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
    _sample(); // prima lettura immediata
  }

  void _sample() {
    final cpuUsage = _reader.sampleCpuUsagePercent();
    final memory = _reader.readMemory();

    if (memory == null) return; // lettura fallita, aspetta il prossimo tick

    _controller.add(HardwareStats(
      // Il primo campione di CPU è sempre null (serve un delta rispetto al
      // precedente) — in quel caso mostriamo 0 invece di lasciare l'HUD vuoto.
      cpuUsagePercent: cpuUsage ?? 0,
      cpuTempCelsius: null, // non disponibile senza driver/companion
      gpuUsagePercent: null, // non disponibile in questa implementazione
      gpuTempCelsius: null,
      ramUsedGb: memory.usedGb,
      ramTotalGb: memory.totalGb,
      cpuName: _cpuName,
      logicalProcessorCount: _logicalProcessorCount,
    ));
  }

  @override
  Stream<HardwareStats> get statsStream => _controller.stream;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

class _CompanionHardwareMonitorService implements HardwareMonitorService {
  final _controller = StreamController<HardwareStats>.broadcast();
  final Uri _endpoint;
  final Duration _pollInterval;
  Timer? _timer;
  HardwareMonitorService? _fallback;

  // Se N richieste consecutive falliscono, passiamo ai dati mock finché
  // il servizio non torna raggiungibile — evita che l'HUD resti vuoto
  // durante lo sviluppo (companion non ancora avviato) o in caso di
  // problemi temporanei.
  static const _maxConsecutiveFailures = 3;
  int _consecutiveFailures = 0;

  _CompanionHardwareMonitorService({
    Uri? endpoint,
    Duration pollInterval = const Duration(seconds: 1),
  })  : _endpoint = endpoint ?? Uri.parse('http://127.0.0.1:5157/stats'),
        _pollInterval = pollInterval {
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll(); // prima lettura immediata, non aspettare il primo tick
  }

  Future<void> _poll() async {
    try {
      final response = await http.get(_endpoint).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _controller.add(HardwareStats.fromJson(json));
        _consecutiveFailures = 0;
        _fallback?.dispose();
        _fallback = null;
        return;
      }
      _onFailure();
    } catch (_) {
      _onFailure();
    }
  }

  void _onFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _maxConsecutiveFailures && _fallback == null) {
      // Companion irraggiungibile: passa temporaneamente ai dati mock.
      _fallback = HardwareMonitorService.mock();
      _fallback!.statsStream.listen((stats) {
        if (!_controller.isClosed) _controller.add(stats);
      });
    }
  }

  @override
  Stream<HardwareStats> get statsStream => _controller.stream;

  @override
  void dispose() {
    _timer?.cancel();
    _fallback?.dispose();
    _controller.close();
  }
}
