import 'dart:math';
import 'package:flutter/material.dart';
import '../services/network_radar_service.dart';
import '../theme/vexon_colors.dart';

/// Radar circolare stile sci-fi con i dispositivi visti di recente sulla
/// rete locale (vedi [NetworkRadarService] per il perché non è una
/// scansione attiva completa). I dispositivi non hanno una posizione
/// reale nello spazio — vengono distribuiti su angoli fissi solo per
/// l'effetto visivo "radar", non rappresentano una posizione fisica.
class NetworkRadar extends StatefulWidget {
  final List<NetworkDevice> devices;
  const NetworkRadar({super.key, required this.devices});

  @override
  State<NetworkRadar> createState() => _NetworkRadarState();
}

class _NetworkRadarState extends State<NetworkRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VexonColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 13, color: VexonColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'RETE LOCALE',
                style: TextStyle(
                  color: VexonColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(120, 120),
                painter: _RadarPainter(devices: widget.devices, sweepT: _controller.value),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.devices.length} DISPOSITIVI',
            style: const TextStyle(
              color: VexonColors.textDisabled,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<NetworkDevice> devices;
  final double sweepT;

  _RadarPainter({required this.devices, required this.sweepT});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final frac in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, radius * frac, ringPaint);
    }
    canvas.drawLine(
        Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), ringPaint);
    canvas.drawLine(
        Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), ringPaint);

    final sweepAngle = sweepT * 2 * pi;

    // Cono di scansione sfumato dietro l'ago — l'effetto "radar" classico.
    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.9,
        endAngle: sweepAngle,
        colors: [VexonColors.success.withOpacity(0.0), VexonColors.success.withOpacity(0.28)],
      ).createShader(sweepRect);
    canvas.drawCircle(center, radius, sweepPaint);

    final needleEnd = Offset(center.dx + radius * cos(sweepAngle), center.dy + radius * sin(sweepAngle));
    final needlePaint = Paint()
      ..color = VexonColors.success.withOpacity(0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(center, needleEnd, needlePaint);

    if (devices.isEmpty) return;

    // Blip dei dispositivi — non abbiamo una posizione reale, quindi sono
    // distribuiti su angoli fissi (equidistanti) con un raggio
    // pseudo-casuale ma deterministico (basato sull'indice, non su
    // Random, altrimenti "salterebbero" ad ogni frame) così non si
    // sovrappongono tutti sullo stesso anello. Si illuminano quando il
    // cono di scansione li attraversa.
    for (var i = 0; i < devices.length; i++) {
      final angle = (i / devices.length) * 2 * pi;
      final r = radius * (0.4 + 0.5 * ((i * 37) % 100) / 100);
      final pos = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));

      var diff = (angle - sweepAngle) % (2 * pi);
      if (diff < 0) diff += 2 * pi;
      final shortestDiff = min(diff, 2 * pi - diff);
      final highlight = shortestDiff < 0.4 ? (1 - shortestDiff / 0.4) : 0.0;

      final brightness = (0.35 + highlight * 0.65).clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..color = VexonColors.success.withOpacity(brightness * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(pos, 5, glowPaint);

      final corePaint = Paint()..color = VexonColors.success.withOpacity(brightness);
      canvas.drawCircle(pos, 2.2, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
