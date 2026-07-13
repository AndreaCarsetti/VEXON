import 'package:flutter/material.dart';
import '../services/hardware_monitor_service.dart';
import '../theme/vexon_colors.dart';
import 'sparkline.dart';

/// HUD hardware con mini-grafici storici (tipo Task Manager) invece dei
/// soli numeri statici — dà molta più sensazione di "diretta" quando i
/// valori cambiano nel tempo.
class HardwareHud extends StatelessWidget {
  final HardwareStats? stats;
  final List<double> cpuHistory;
  final List<double> gpuHistory;
  final List<double> ramHistory;

  const HardwareHud({
    super.key,
    this.stats,
    this.cpuHistory = const [],
    this.gpuHistory = const [],
    this.ramHistory = const [],
  });

  Color _colorForValue(double? percent) {
    if (percent == null) return VexonColors.textSecondary;
    if (percent < 60) return VexonColors.success;
    if (percent < 85) return VexonColors.warning;
    return VexonColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VexonColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: s == null
          ? const SizedBox(
              height: 24,
              child: Center(
                child: Text('In attesa dati hardware…',
                    style: TextStyle(color: VexonColors.textSecondary, fontSize: 12)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _metricRow('CPU', s.cpuUsagePercent, _tempLabel(s.cpuTempCelsius), cpuHistory),
                const SizedBox(height: 10),
                _metricRow('GPU', s.gpuUsagePercent, _tempLabel(s.gpuTempCelsius), gpuHistory),
                const SizedBox(height: 10),
                _metricRow('RAM', s.ramUsagePercent,
                    '${s.ramUsedGb.toStringAsFixed(1)}/${s.ramTotalGb.toStringAsFixed(0)}GB', ramHistory),
              ],
            ),
    );
  }

  String _tempLabel(double? temp) => temp == null ? 'N/D' : '${temp.toStringAsFixed(0)}°C';

  /// [percent] può essere `null` (dato non disponibile senza il companion
  /// service) — mostriamo "N/D" e nessun grafico invece di inventare dati.
  Widget _metricRow(String label, double? percent, String detail, List<double> history) {
    final color = _colorForValue(percent);
    final percentLabel = percent == null ? 'N/D' : '${percent.toStringAsFixed(0)}%';

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: VexonColors.textSecondary, fontSize: 10, letterSpacing: 0.5)),
              Text('$percentLabel  ·  $detail',
                  style: const TextStyle(
                      color: VexonColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (history.length >= 2)
          Sparkline(values: history, color: color, width: 64, height: 26)
        else
          const SizedBox(width: 64, height: 26),
      ],
    );
  }
}
