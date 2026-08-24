import 'dart:math';
import 'package:flutter/material.dart';
import '../services/hardware_monitor_service.dart';
import '../theme/vexon_colors.dart';
import 'sparkline.dart';

/// HUD hardware in stile "centro di controllo": pannello smussato
/// asimmetrico, quadranti radiali con anello esterno rotante continuo,
/// bordo con traccia luminosa che ne percorre il perimetro, picchi storici
/// e RAM libera, orologio live, uptime/sessione.
class HardwareHud extends StatefulWidget {
  final HardwareStats? stats;
  final List<double> cpuHistory;
  final List<double> gpuHistory;
  final List<double> ramHistory;
  final String? gpuName;
  final double? gpuUsagePercent;

  const HardwareHud({
    super.key,
    this.stats,
    this.cpuHistory = const [],
    this.gpuHistory = const [],
    this.ramHistory = const [],
    this.gpuName,
    this.gpuUsagePercent,
  });

  @override
  State<HardwareHud> createState() => _HardwareHudState();
}

class _HardwareHudState extends State<HardwareHud> with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;
  late final DateTime _startTime;
  late final String _sessionTag;

  static const _chamferCut = 18.0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _sessionTag = Random().nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
    // Un solo controller in loop guida scanline, traccia perimetrale,
    // rotazione degli anelli esterni e pulsazioni — tutto sincronizzato
    // sullo stesso "battito".
    _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  Color _colorForValue(double? percent) {
    if (percent == null) return VexonColors.textSecondary;
    if (percent < 60) return VexonColors.success;
    if (percent < 85) return VexonColors.warning;
    return VexonColors.critical;
  }

  String _tempLabel(double? temp) => temp == null ? 'N/D' : '${temp.toStringAsFixed(0)}°C';

  String _uptimeLabel() {
    final d = DateTime.now().difference(_startTime);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  double? _peak(List<double> history) {
    if (history.isEmpty) return null;
    return history.reduce(max);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;

    final available = [s?.cpuUsagePercent, widget.gpuUsagePercent ?? s?.gpuUsagePercent, s?.ramUsagePercent]
        .whereType<double>()
        .toList();
    final worst = available.isEmpty ? null : available.reduce(max);
    final statusColor = _colorForValue(worst);
    final statusLabel = worst == null
        ? 'IN ATTESA'
        : worst < 60
            ? 'NOMINALE'
            : worst < 85
                ? 'ELEVATO'
                : 'CRITICO';

    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, _) {
        final t = _ambient.value;
        final pulse = 0.85 + 0.15 * (1 - (2 * t - 1).abs());

        return Container(
          width: 340,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipPath(
            clipper: _ChamferClipper(cut: _chamferCut),
            child: Container(
              color: VexonColors.surface.withOpacity(0.94),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HudFramePainter(sweepT: t, accent: VexonColors.brandRed, cut: _chamferCut),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s == null)
                          const SizedBox(
                            height: 90,
                            child: Center(
                              child: Text('IN ATTESA DATI HARDWARE…',
                                  style: TextStyle(
                                      color: VexonColors.textSecondary, fontSize: 11, letterSpacing: 1)),
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Transform.scale(
                                scale: pulse,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: statusColor.withOpacity(0.7), blurRadius: 7),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'SYSTEM MONITOR',
                                style: TextStyle(
                                  color: VexonColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _gaugeColumn(
                                label: 'CPU',
                                value: s.cpuUsagePercent,
                                detail: _tempLabel(s.cpuTempCelsius),
                                peak: _peak(widget.cpuHistory),
                                history: widget.cpuHistory,
                                glow: pulse,
                                rotation: t * 2 * pi,
                              ),
                              _gaugeColumn(
                                label: 'GPU',
                                value: widget.gpuUsagePercent ?? s.gpuUsagePercent,
                                detail: _tempLabel(s.gpuTempCelsius),
                                peak: _peak(widget.gpuHistory),
                                history: widget.gpuHistory,
                                glow: pulse,
                                rotation: -t * 2 * pi,
                              ),
                              _gaugeColumn(
                                label: 'RAM',
                                value: s.ramUsagePercent,
                                detail:
                                    '${s.ramUsedGb.toStringAsFixed(1)}/${s.ramTotalGb.toStringAsFixed(0)}GB',
                                peak: _peak(widget.ramHistory),
                                history: widget.ramHistory,
                                glow: pulse,
                                rotation: t * 2 * pi,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'RAM LIBERA ${(s.ramTotalGb - s.ramUsedGb).toStringAsFixed(1)}GB',
                            style: const TextStyle(
                              color: VexonColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (s.cpuName != null) ...[
                            const SizedBox(height: 12),
                            Container(height: 1, color: Colors.white10),
                            const SizedBox(height: 10),
                            Text(
                              s.cpuName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VexonColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (s.logicalProcessorCount != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${s.logicalProcessorCount} THREAD LOGICI',
                                style: const TextStyle(
                                  color: VexonColors.textDisabled,
                                  fontSize: 9,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ],
                          if (widget.gpuName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.gpuName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VexonColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(height: 1, color: Colors.white10),
                          const SizedBox(height: 8),
                          Text(
                            'UPTIME ${_uptimeLabel()}  ·  SESSION #$_sessionTag',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: VexonColors.textDisabled,
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gaugeColumn({
    required String label,
    required double? value,
    required String detail,
    required double? peak,
    required List<double> history,
    required double glow,
    required double rotation,
  }) {
    final color = _colorForValue(value);
    final peakLabel = peak == null ? null : 'PICCO ${peak.toStringAsFixed(0)}%';
    return Column(
      children: [
        _RadialGauge(value: value, color: color, glow: glow, rotation: rotation, size: 78),
        const SizedBox(height: 7),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(detail, style: const TextStyle(color: VexonColors.textSecondary, fontSize: 10)),
        if (peakLabel != null) ...[
          const SizedBox(height: 1),
          Text(peakLabel, style: const TextStyle(color: VexonColors.textDisabled, fontSize: 9)),
        ],
        const SizedBox(height: 6),
        if (history.length >= 2)
          Sparkline(values: history, color: color, width: 72, height: 18)
        else
          const SizedBox(width: 72, height: 18),
      ],
    );
  }
}

/// Quadrante radiale: arco a 270° con alone luminoso e cursore sulla
/// punta, tacche di scala, e un anello esterno tratteggiato che ruota in
/// continuazione (indipendente dal valore) per il tipico effetto
/// "scansione sempre attiva".
class _RadialGauge extends StatelessWidget {
  final double? value;
  final Color color;
  final double glow;
  final double rotation;
  final double size;

  const _RadialGauge({
    required this.value,
    required this.color,
    required this.glow,
    required this.rotation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RadialGaugePainter(value: value, color: color, glow: glow, rotation: rotation),
          ),
          Text(
            value == null ? '--' : value!.toStringAsFixed(0),
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: size * 0.26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double? value;
  final Color color;
  final double glow;
  final double rotation;

  _RadialGaugePainter({
    required this.value,
    required this.color,
    required this.glow,
    required this.rotation,
  });

  static const _startAngle = pi * 0.75;
  static const _sweepTotal = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final outerRect = Rect.fromCircle(center: center, radius: radius + 7);
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashCount = 22;
    const dashLength = (2 * pi / dashCount) * 0.45;
    for (var i = 0; i < dashCount; i++) {
      final a0 = rotation + i * (2 * pi / dashCount);
      canvas.drawArc(outerRect, a0, dashLength, false, dashPaint);
    }

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepTotal, false, trackPaint);

    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.3;
    for (var i = 0; i <= 10; i++) {
      final angle = _startAngle + _sweepTotal * (i / 10);
      final inner = Offset(center.dx + (radius - 1) * cos(angle), center.dy + (radius - 1) * sin(angle));
      final outer = Offset(center.dx + (radius + 3) * cos(angle), center.dy + (radius + 3) * sin(angle));
      canvas.drawLine(inner, outer, tickPaint);
    }

    final v = value;
    if (v == null) return;

    final fraction = v.clamp(0, 100) / 100;
    final sweep = _sweepTotal * fraction;
    final endAngle = _startAngle + sweep;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.45 + glow * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawArc(rect, _startAngle, sweep, false, glowPaint);

    final valuePaint = Paint()
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepTotal,
        colors: [color.withOpacity(0.55), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, sweep, false, valuePaint);

    final tip = Offset(center.dx + radius * cos(endAngle), center.dy + radius * sin(endAngle));
    canvas.drawCircle(
      tip,
      5.5,
      Paint()
        ..color = color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) => true;
}

/// Ritaglia il pannello con due angoli smussati (alto-sinistra e
/// basso-destra) invece di un rettangolo pieno.
class _ChamferClipper extends CustomClipper<Path> {
  final double cut;
  const _ChamferClipper({required this.cut});

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ChamferClipper oldClipper) => oldClipper.cut != cut;
}

/// Cornice del pannello: bordo smussato lungo lo stesso profilo del
/// ritaglio, angoli da mirino, griglia leggerissima, scanline in loop, e
/// una traccia luminosa che percorre il perimetro come un circuito che si
/// ricarica.
class _HudFramePainter extends CustomPainter {
  final double sweepT;
  final Color accent;
  final double cut;

  _HudFramePainter({required this.sweepT, required this.accent, required this.cut});

  Path _panelPath(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final panelPath = _panelPath(size);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(panelPath, borderPaint);

    const bracketLen = 14.0;
    final bracketPaint = Paint()
      ..color = accent.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - bracketLen, 0), bracketPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, bracketLen), bracketPaint);
    canvas.drawLine(Offset(0, size.height), Offset(bracketLen, size.height), bracketPaint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - bracketLen), bracketPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanY = size.height * sweepT;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accent.withOpacity(0.0), accent.withOpacity(0.14), accent.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, scanY - 18, size.width, 36));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 18, size.width, 36), scanPaint);

    final metrics = panelPath.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      const traceLen = 52.0;
      final start = sweepT * metric.length;
      final end = min(start + traceLen, metric.length);
      if (end > start) {
        final tracePath = metric.extractPath(start, end);
        final tracePaint = Paint()
          ..color = accent.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawPath(tracePath, tracePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HudFramePainter oldDelegate) => true;
}
