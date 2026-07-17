import 'dart:math';
import 'package:flutter/material.dart';
import '../services/horror_audio_service.dart';
import '../theme/vexon_colors.dart';
import 'splash_screen.dart';

/// Sequenza di avvio "accensione": scintille ember (la stessa estetica già
/// usata in `particle_background.dart` e nel cursore personalizzato) che
/// partono dai bordi dello schermo e convergono verso il centro, andando a
/// formare il contorno della V del logo. Un lampo le "accende",
/// trasformandole nel logo vero e proprio, che si assesta con un bagliore
/// stabile prima di passare allo splash.
///
/// A differenza dei tentativi precedenti (CRT, horror, terremoto, Matrix),
/// questa sequenza usa lo STESSO linguaggio visivo già presente nel resto
/// dell'app — niente estetica nuova introdotta apposta per il boot.
///
/// Fase 1 (0-62%): le scintille convergono dai bordi verso il contorno
///                 della V
/// Fase 2 (62-75%): lampo di accensione, dissolvenza incrociata verso il
///                  logo reale
/// Fase 3 (75-100%): il logo resta fermo con un bagliore che pulsa piano
class BootSequenceScreen extends StatefulWidget {
  const BootSequenceScreen({super.key});

  @override
  State<BootSequenceScreen> createState() => _BootSequenceScreenState();
}

class _Ember {
  final Offset start; // coordinate relative allo schermo (0-1)
  final Offset target; // punto sul contorno della V, relativo al box del logo
  final double delay; // 0-1, ritardo di partenza entro la fase 1
  final double size;

  _Ember({
    required this.start,
    required this.target,
    required this.delay,
    required this.size,
  });
}

class _BootSequenceScreenState extends State<BootSequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;
  bool _soundPlayed = false;

  static const _totalDuration = Duration(milliseconds: 3400);
  static const _convergeEnd = 0.62;
  static const _igniteEnd = 0.75;

  // Box (in px, relativo al centro schermo) dove si forma il contorno
  // della V — dimensioni scelte per restare vicine a come apparirà poi il
  // logo reale in `assets/icons/logo_splash.png`.
  static const _vBoxWidth = 200.0;
  static const _vBoxHeight = 170.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    _generateEmbers();

    HorrorAudioService.initialize();
    _controller.addListener(_checkAudioCue);

    // Registrato SUBITO, in modo sincrono — su Windows la finestra diventa
    // visibile prima che Flutter disegni il primo frame; farlo dopo
    // un'attesa asincrona rischia di lasciare l'app ferma su schermo nero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward().whenComplete(_goToSplash);
    });
  }

  void _generateEmbers() {
    final rnd = Random(33); // seed fisso: pattern coerente ad ogni avvio
    final targets = _generateVOutlinePoints()..shuffle(rnd);

    _embers = targets.map((target) {
      return _Ember(
        start: _randomEdgePoint(rnd),
        target: target,
        delay: rnd.nextDouble() * 0.28,
        size: 1.6 + rnd.nextDouble() * 2.6,
      );
    }).toList();
  }

  /// Punti campionati lungo le due "lame" della V, in coordinate relative
  /// al box del logo (0,0 = angolo in alto a sinistra del box, 1,1 = in
  /// basso a destra) — una V semplice a due segmenti, sufficiente per far
  /// riconoscere la forma mentre le scintille la disegnano.
  List<Offset> _generateVOutlinePoints() {
    const samplesPerStroke = 40;
    final points = <Offset>[];

    for (var i = 0; i <= samplesPerStroke; i++) {
      final t = i / samplesPerStroke;
      points.add(Offset.lerp(const Offset(0.28, 0.08), const Offset(0.5, 0.92), t)!);
    }
    for (var i = 0; i <= samplesPerStroke; i++) {
      final t = i / samplesPerStroke;
      points.add(Offset.lerp(const Offset(0.72, 0.08), const Offset(0.5, 0.92), t)!);
    }
    return points;
  }

  /// Un punto casuale lungo il perimetro dello schermo (leggermente fuori
  /// dai bordi), in coordinate relative allo schermo intero.
  Offset _randomEdgePoint(Random rnd) {
    final side = rnd.nextInt(4);
    final t = rnd.nextDouble();
    switch (side) {
      case 0:
        return Offset(t, -0.06); // sopra
      case 1:
        return Offset(t, 1.06); // sotto
      case 2:
        return Offset(-0.06, t); // sinistra
      default:
        return Offset(1.06, t); // destra
    }
  }

  void _checkAudioCue() {
    final elapsedMs = _controller.value * _totalDuration.inMilliseconds;
    final igniteMs = _convergeEnd * _totalDuration.inMilliseconds;
    if (!_soundPlayed && elapsedMs >= igniteMs) {
      _soundPlayed = true;
      HorrorAudioService.playLogoImpact();
    }
  }

  void _goToSplash() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const SplashScreen(startVisible: true),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _interval(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          final convergeT =
              Curves.easeOut.transform(_interval(t, 0.0, _convergeEnd));
          final emberOpacity =
              1 - Curves.easeIn.transform(_interval(t, _convergeEnd, _igniteEnd));

          // Il lampo d'accensione: sale rapido e si dissolve.
          final ignitePhase = _interval(t, _convergeEnd, _convergeEnd + 0.06);
          final igniteFlash = ignitePhase > 0 && ignitePhase < 1
              ? sin(ignitePhase * pi) // sale e scende in una curva morbida
              : 0.0;

          // Il logo reale sfuma dentro subito dopo l'accensione, e da lì
          // resta visibile con un lieve bagliore che pulsa piano.
          final logoOpacity =
              Curves.easeOut.transform(_interval(t, _convergeEnd, _igniteEnd));
          final steadyGlow = t > _igniteEnd
              ? 0.5 + 0.5 * sin((t - _igniteEnd) * 6)
              : 0.0;

          return LayoutBuilder(
            builder: (context, constraints) {
              final center =
                  Offset(constraints.maxWidth / 2, constraints.maxHeight / 2 - 20);

              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  if (emberOpacity > 0)
                    CustomPaint(
                      painter: _EmberFormationPainter(
                        embers: _embers,
                        convergeT: convergeT,
                        opacity: emberOpacity,
                        center: center,
                        boxWidth: _vBoxWidth,
                        boxHeight: _vBoxHeight,
                        screenSize: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                  if (igniteFlash > 0)
                    Center(
                      child: Container(
                        width: 60 + igniteFlash * 500,
                        height: 60 + igniteFlash * 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(igniteFlash * 0.9),
                              VexonColors.brandRed.withOpacity(igniteFlash * 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (logoOpacity > 0)
                    Center(
                      child: Opacity(
                        opacity: logoOpacity,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: VexonColors.brandRed
                                    .withOpacity(0.35 + steadyGlow * 0.25),
                                blurRadius: 40 + steadyGlow * 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset('assets/icons/logo_splash.png', width: 300),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Disegna le scintille mentre convergono dai bordi dello schermo verso il
/// contorno della V — stesso stile ember (alone rosso + nucleo ambra) già
/// usato in `particle_background.dart`, per coerenza visiva con il resto
/// dell'app.
class _EmberFormationPainter extends CustomPainter {
  final List<_Ember> embers;
  final double convergeT;
  final double opacity;
  final Offset center;
  final double boxWidth;
  final double boxHeight;
  final Size screenSize;

  static const _emberCore = Color(0xFFFFA552);

  _EmberFormationPainter({
    required this.embers,
    required this.convergeT,
    required this.opacity,
    required this.center,
    required this.boxWidth,
    required this.boxHeight,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    for (final ember in embers) {
      final localT =
          ((convergeT - ember.delay) / (1 - ember.delay)).clamp(0.0, 1.0);
      final eased = Curves.easeInOutCubic.transform(localT);

      final startPx = Offset(ember.start.dx * screenSize.width, ember.start.dy * screenSize.height);
      final targetPx = Offset(
        center.dx - boxWidth / 2 + ember.target.dx * boxWidth,
        center.dy - boxHeight / 2 + ember.target.dy * boxHeight,
      );

      final pos = Offset.lerp(startPx, targetPx, eased)!;
      final localOpacity = (0.4 + eased * 0.6) * opacity;

      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(localOpacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(pos, ember.size * 2.0, glowPaint);

      final corePaint = Paint()..color = _emberCore.withOpacity(localOpacity * 0.85);
      canvas.drawCircle(pos, ember.size * 0.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberFormationPainter oldDelegate) => true;
}
