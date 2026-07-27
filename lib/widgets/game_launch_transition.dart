import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/vexon_colors.dart';

/// Overlay mostrato mentre un gioco sta per avviarsi.
///
/// PERCHÉ SERVE: VEXON gira come "shell" in modalità kiosk — finestra
/// fullscreen sempre in primo piano — apposta per sostituire il desktop.
/// Ma questo significa che, senza intervenire, resterebbe sopra anche al
/// gioco appena lanciato, che non riuscirebbe mai a comparire in primo
/// piano. La soluzione: si mostra questa schermata di caricamento per una
/// durata fissa (vedi [duration] — non c'è modo affidabile di sapere
/// quando la finestra del gioco è realmente pronta, specialmente per i
/// giochi Steam lanciati via protocollo, dove VEXON non ha nessuna
/// visibilità sul processo reale del gioco), e SOLO alla fine di questa
/// finestra temporale il chiamante toglie l'always-on-top e minimizza
/// VEXON, lasciando emergere il gioco.
///
/// Se il gioco impiega più della [duration] a comparire (capita con
/// titoli AAA pesanti), per quei pochi secondi in più si vedrà il desktop
/// invece del gioco — limite intrinseco di questo approccio, condiviso del
/// resto da molti launcher reali (anche loro minimizzano appena lanciato
/// il processo, senza aspettare che la finestra sia visibile).
class GameLaunchTransition extends StatefulWidget {
  final Game game;
  final Duration duration;
  final VoidCallback onCompleted;

  const GameLaunchTransition({
    super.key,
    required this.game,
    required this.onCompleted,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<GameLaunchTransition> createState() => _GameLaunchTransitionState();
}

class _GameLaunchTransitionState extends State<GameLaunchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    // Timer indipendente dal loop dell'animazione: la rotazione/pulsazione
    // continua a ciclo mentre un secondo timer, con la durata totale
    // richiesta, decide quando avvisare il chiamante.
    _completionTimer = Timer(widget.duration, widget.onCompleted);
  }

  @override
  void dispose() {
    _controller.dispose();
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.game.coverImagePath;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Sfondo: la cover del gioco, sfocata e scurita, se disponibile —
          // dà un riferimento visivo immediato di "quale gioco" sta
          // partendo invece di un semplice buio uniforme.
          if (coverUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(coverUrl != null ? 0.72 : 0.92)),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final pulse = 0.94 + 0.06 * (1 - (2 * t - 1).abs());
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: t * 2 * pi,
                            child: CustomPaint(
                              size: const Size(88, 88),
                              painter: _LaunchRingPainter(color: VexonColors.brandRed),
                            ),
                          ),
                          Transform.scale(
                            scale: pulse,
                            child: const Icon(Icons.sports_esports, size: 36, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AVVIO DI ${widget.game.title.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Il gioco comparirà a breve…',
                      style: TextStyle(color: VexonColors.textSecondary, fontSize: 13),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchRingPainter extends CustomPainter {
  final Color color;
  const _LaunchRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.0), color.withOpacity(0.9)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect.deflate(4), 0, 3.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LaunchRingPainter oldDelegate) => false;
}
