import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/vexon_colors.dart';

/// Sfondo animato con particelle luminose che fluttuano lentamente verso
/// l'alto, in stile "braci/scintille" coerente col bagliore rosso del logo
/// VEXON. Pensato per stare DIETRO al contenuto principale (griglia
/// giochi), quindi con opacità bassa per non compromettere la leggibilità.
///
/// Dettaglio implementativo importante: usa un `Ticker` + `ValueNotifier`
/// invece di un `setState` nel widget stesso — così ad ogni frame si
/// ridisegna SOLO il `CustomPaint` delle particelle, non l'intero
/// `widget.child` (che nel nostro caso è tutta la home screen). Con un
/// `setState` normale, ricostruire l'intera schermata a 60fps per animare
/// solo un puntino sarebbe uno spreco enorme di prestazioni.
class ParticleBackground extends StatefulWidget {
  final Widget? child;
  final int particleCount;

  const ParticleBackground({super.key, this.child, this.particleCount = 22});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _particles = List.generate(widget.particleCount, (_) => _Particle.random(rnd));
    _ticker = createTicker((elapsed) => _elapsed.value = elapsed);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<Duration>(
            valueListenable: _elapsed,
            builder: (context, elapsed, _) {
              return CustomPaint(
                painter: _ParticlePainter(particles: _particles, elapsed: elapsed),
              );
            },
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Stato di una singola particella, in coordinate RELATIVE (0.0-1.0)
/// rispetto alla dimensione del canvas — così l'animazione si adatta
/// automaticamente a qualunque risoluzione senza ricalcoli.
class _Particle {
  final double startX;
  final double startY;
  final double speed; // quanto "avanza" per secondo, in unità relative
  final double swayAmplitude; // ampiezza dell'oscillazione orizzontale
  final double swaySpeed;
  final double radius;
  final double baseOpacity;
  final double phaseOffset;

  _Particle({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.swayAmplitude,
    required this.swaySpeed,
    required this.radius,
    required this.baseOpacity,
    required this.phaseOffset,
  });

  factory _Particle.random(Random rnd) {
    return _Particle(
      startX: rnd.nextDouble(),
      startY: rnd.nextDouble(),
      speed: 0.008 + rnd.nextDouble() * 0.02, // lento: sale per tutto lo schermo in decine di secondi
      swayAmplitude: 0.01 + rnd.nextDouble() * 0.02,
      swaySpeed: 0.3 + rnd.nextDouble() * 0.6,
      radius: 2.2 + rnd.nextDouble() * 4.8,
      baseOpacity: 0.55 + rnd.nextDouble() * 0.4,
      phaseOffset: rnd.nextDouble() * 2 * pi,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Duration elapsed;

  _ParticlePainter({required this.particles, required this.elapsed});

  @override
  void paint(Canvas canvas, Size size) {
    final t = elapsed.inMilliseconds / 1000.0;

    for (final p in particles) {
      // Risale lentamente verso l'alto, con un leggero ondeggiamento
      // orizzontale a base sinusoidale — dà un moto organico invece che
      // una traiettoria rettilinea meccanica.
      final progress = (p.startY - p.speed * t) % 1.0;
      final y = progress < 0 ? progress + 1.0 : progress;
      final sway = sin(t * p.swaySpeed + p.phaseOffset) * p.swayAmplitude;
      final x = (p.startX + sway) % 1.0;

      // Le particelle si affievoliscono vicino al bordo superiore, per
      // sparire gradualmente invece di scomparire di scatto quando il
      // ciclo si ripete dal basso.
      final fadeNearTop = (y < 0.08) ? (y / 0.08) : 1.0;
      final opacity = p.baseOpacity * fadeNearTop;

      final center = Offset(x * size.width, y * size.height);

      // Colore "brace": nucleo caldo ambra/arancione che sfuma nel rosso
      // del brand verso l'esterno — più coerente con un vero effetto
      // scintilla rispetto a un nucleo bianco puro (troppo freddo/elettrico).
      const emberCore = Color(0xFFFFA552); // ambra calda

      // Alone sfumato rosso (più ampio, sfocato)...
      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(opacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(center, p.radius * 2.0, glowPaint);

      // ...più un nucleo ambra, più piccolo e nitido, per l'effetto brace.
      final corePaint = Paint()..color = emberCore.withOpacity(opacity * 0.85);
      canvas.drawCircle(center, p.radius * 0.45, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
