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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _igniteController;
  late final List<_Spark> _sparks;
  Timer? _completionTimer;

  static const _emberCore = Color(0xFFFFA552); // stesso ambra usato nel boot

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    // Piccola "accensione" a scintille, stesso linguaggio visivo del boot
    // sequence (converge → lampo) ma compressa in meno di un secondo: lega
    // il momento del lancio di un gioco alla stessa identità del brand,
    // invece di essere un evento isolato con un'estetica propria.
    _igniteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
      ..forward();
    _sparks = _generateSparks();
    // Timer indipendente dal loop dell'animazione: la rotazione/pulsazione
    // continua a ciclo mentre un secondo timer, con la durata totale
    // richiesta, decide quando avvisare il chiamante.
    _completionTimer = Timer(widget.duration, widget.onCompleted);
  }

  List<_Spark> _generateSparks() {
    final rnd = Random();
    return List.generate(16, (_) {
      return _Spark(
        angle: rnd.nextDouble() * 2 * pi,
        radius: 70 + rnd.nextDouble() * 70,
        delay: rnd.nextDouble() * 0.35,
        size: 1.6 + rnd.nextDouble() * 2.2,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _igniteController.dispose();
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
              animation: Listenable.merge([_controller, _igniteController]),
              builder: (context, _) {
                final t = _controller.value;
                final pulse = 0.94 + 0.06 * (1 - (2 * t - 1).abs());
                final igniteT = _igniteController.value;

                // Fase scintille: convergono verso il centro fino a metà
                // animazione, poi svaniscono rapidamente.
                final convergeT = Curves.easeInCubic.transform(igniteT.clamp(0.0, 0.55) / 0.55);
                final sparksOpacity = 1 - Curves.easeIn.transform(
                    ((igniteT - 0.45) / 0.25).clamp(0.0, 1.0));

                // Lampo d'accensione: sale e scende rapido intorno al
                // momento in cui le scintille arrivano al centro.
                final flashPhase = ((igniteT - 0.45) / 0.3).clamp(0.0, 1.0);
                final igniteFlash = flashPhase > 0 && flashPhase < 1 ? sin(flashPhase * pi) : 0.0;

                // L'icona/anello di caricamento emerge subito dopo il
                // lampo, invece di essere visibile fin dal primo frame —
                // dà l'idea che sia lei stessa ad "accendersi".
                final revealT = Curves.easeOut.transform(((igniteT - 0.55) / 0.45).clamp(0.0, 1.0));

                return SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (sparksOpacity > 0)
                        CustomPaint(
                          size: const Size(240, 240),
                          painter: _SparkBurstPainter(
                            sparks: _sparks,
                            convergeT: convergeT,
                            opacity: sparksOpacity,
                            emberCore: _emberCore,
                          ),
                        ),
                      if (igniteFlash > 0)
                        Container(
                          width: 40 + igniteFlash * 160,
                          height: 40 + igniteFlash * 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(igniteFlash * 0.85),
                                VexonColors.brandRed.withOpacity(igniteFlash * 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      Opacity(
                        opacity: revealT,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * revealT,
                          child: Column(
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
                                      child: const Icon(Icons.sports_esports,
                                          size: 36, color: Colors.white),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double radius;
  final double delay;
  final double size;

  _Spark({required this.angle, required this.radius, required this.delay, required this.size});
}

/// Scintille che convergono verso il centro per "accendere" l'icona di
/// avvio — stesso stile ember (alone rosso + nucleo ambra) usato in
/// `boot_sequence_screen.dart` e `particle_background.dart`.
class _SparkBurstPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double convergeT;
  final double opacity;
  final Color emberCore;

  _SparkBurstPainter({
    required this.sparks,
    required this.convergeT,
    required this.opacity,
    required this.emberCore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = size.center(Offset.zero);

    for (final spark in sparks) {
      final localT = ((convergeT - spark.delay) / (1 - spark.delay)).clamp(0.0, 1.0);
      final eased = Curves.easeInOutCubic.transform(localT);

      final start = center + Offset(cos(spark.angle), sin(spark.angle)) * spark.radius;
      final pos = Offset.lerp(start, center, eased)!;
      final localOpacity = (0.4 + eased * 0.6) * opacity;

      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(localOpacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(pos, spark.size * 2.0, glowPaint);

      final corePaint = Paint()..color = emberCore.withOpacity(localOpacity * 0.85);
      canvas.drawCircle(pos, spark.size * 0.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkBurstPainter oldDelegate) => true;
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
