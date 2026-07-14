import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';
import '../services/horror_audio_service.dart';
import 'splash_screen.dart';

/// Sequenza di avvio HORROR INTENSE: 2 occhi rossi che si aprono nel buio,
/// poi 4 creature ombra dai 4 angoli che convergono VIOLENTEMENTE verso il
/// centro con sussulti e lampi rossi, prima di un impatto che frattura lo
/// schermo — crepe che si propagano dal centro nel buio, poi il logo VEXON
/// emerge attraverso di esse.
/// 
/// Fase 1 (0-0.15): Occhi che si aprono lentamente dal nero
/// Fase 2 (0.15-0.55): Creature convergono con movimento aggressivo e sussulti,
///                      lampi rossi random
/// Fase 3 (0.55-0.75): Creature si contraggono verso il centro, lampi intensi
/// Fase 4 (0.75-1.0): Impatto rosso breve → crepe che si propagano nel buio →
///                     il logo emerge attraverso di esse
class BootSequenceScreen extends StatefulWidget {
  const BootSequenceScreen({super.key});

  @override
  State<BootSequenceScreen> createState() => _BootSequenceScreenState();
}

class _BootSequenceScreenState extends State<BootSequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<double> _flashTimes;
  late final List<List<Offset>> _crackBranches;
  late final List<double> _crackDelays;

  static const _totalDuration = Duration(milliseconds: 2600);
  static const _eyesEnd = 0.15;
  static const _creaturesEnd = 0.55;
  static const _contractEnd = 0.75;
  static const _logoEnd = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    _generateFlashes();
    _generateCracks();
    HorrorAudioService.initialize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward().whenComplete(_goToSplash);
      _setupAudioTimings();
    });
  }

  void _generateFlashes() {
    final rnd = Random(42);
    _flashTimes = List.generate(
      12,
      (_) => 0.15 + rnd.nextDouble() * 0.6, // Lampi dopo gli occhi
    );
  }

  /// Genera le crepe una sola volta, con seed fisso — il pattern di
  /// frattura resta identico ad ogni avvio invece di essere diverso ogni
  /// volta. Ogni crepa è una sequenza di punti in "unità di raggio"
  /// (centro = 0, bordo schermo ≈ 1), così si adatta a qualunque
  /// risoluzione scalandola per le dimensioni reali solo al momento del
  /// disegno.
  void _generateCracks() {
    final rnd = Random(13);
    const branchCount = 9;

    _crackBranches = List.generate(branchCount, (i) {
      final baseAngle = (i / branchCount) * 2 * pi + (rnd.nextDouble() - 0.5) * 0.4;
      return _buildCrackBranch(rnd, baseAngle);
    });

    // Partenze leggermente scaglionate: non tutte le crepe crescono
    // insieme, danno l'idea di una frattura che si diffonde nel tempo.
    _crackDelays = List.generate(branchCount, (_) => rnd.nextDouble() * 0.35);
  }

  List<Offset> _buildCrackBranch(Random rnd, double baseAngle) {
    final points = <Offset>[Offset.zero];
    var angle = baseAngle;
    var radius = 0.0;
    final segments = 5 + rnd.nextInt(3);

    for (var s = 0; s < segments; s++) {
      // La direzione "deriva" ad ogni segmento — è quello che dà l'aspetto
      // spezzato/irregolare tipico di una crepa nel vetro, invece di una
      // linea retta.
      angle += (rnd.nextDouble() - 0.5) * 0.6;
      radius += 0.12 + rnd.nextDouble() * 0.09;
      points.add(Offset(cos(angle) * radius, sin(angle) * radius));
    }
    return points;
  }

  /// Schedulerà i suoni ai tempi di animazione corretti
  void _setupAudioTimings() {
    Future.delayed(Duration(milliseconds: 150), () {
      HorrorAudioService.playSound('eyes_open');
    });
    Future.delayed(Duration(milliseconds: 400), () {
      HorrorAudioService.playSound('creature_approach');
    });
    Future.delayed(Duration(milliseconds: 950), () {
      HorrorAudioService.playSound('chaos_peak');
    });
    Future.delayed(Duration(milliseconds: 1950), () {
      HorrorAudioService.playSound('white_flash');
    });
  }

  void _goToSplash() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        // Il logo è già comparso attraverso le crepe nella fase finale di
        // questo boot — SplashScreen deve mostrarlo già a piena opacità
        // (niente secondo fade-in da zero), altrimenti si vedrebbe
        // sparire di scatto e ricomparire.
        pageBuilder: (_, __, ___) => const SplashScreen(startVisible: true),
      ),
    );
  }

  @override
  void dispose() {
    HorrorAudioService.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final size = MediaQuery.of(context).size;

          // Effetto di vibrazione dello schermo
          final jitterX = (sin(t * 180) * 0.05).clamp(-0.03, 0.03);
          final jitterY = (cos(t * 150) * 0.05).clamp(-0.03, 0.03);

          return Transform.translate(
            offset: Offset(jitterX * size.width, jitterY * size.height),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Sfondo nero base
                const ColoredBox(color: Colors.black),

                // Lampi rossi improvvisi (random durante il caos)
                ..._flashTimes
                    .where((flashT) => (t - flashT).abs() < 0.08)
                    .map((flashT) {
                  final flashIntensity =
                      (1.0 - ((t - flashT).abs() / 0.08)).clamp(0.0, 1.0);
                  return ColoredBox(
                    color: VexonColors.brandRed.withOpacity(flashIntensity * 0.5),
                  );
                }),

                // 2 OCCHI ROSSI che si aprono
                if (t < _eyesEnd)
                  _buildEyes(t / _eyesEnd, size),

                // 4 creature dai 4 angoli (movimento VIOLENTO)
                if (t >= _eyesEnd && t < _contractEnd)
                  _buildCreatures(
                    (t - _eyesEnd) / (_contractEnd - _eyesEnd),
                    size,
                  ),

                // Dissolvenza bianca finale + logo
                if (t >= _contractEnd)
                  _buildFinalPhase(
                    (t - _contractEnd) / (_logoEnd - _contractEnd),
                    size,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 2 occhi rossi che si aprono lentamente dal nero
  Widget _buildEyes(double t, Size size) {
    final eyeSize = 80 * Curves.easeInOut.transform(t);
    final eyeOpacity = Curves.easeOut.transform(t);
    final glowSize = 200 * Curves.easeInOut.transform(t);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow rosso esterno
          Container(
            width: glowSize,
            height: glowSize / 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  VexonColors.brandRed.withOpacity(eyeOpacity * 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Occhio sinistro
          Positioned(
            left: size.width / 2 - 80,
            child: Opacity(
              opacity: eyeOpacity,
              child: Container(
                width: eyeSize,
                height: eyeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VexonColors.brandRed,
                  boxShadow: [
                    BoxShadow(
                      color: VexonColors.brandRed.withOpacity(0.8),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: eyeSize * 0.4,
                    height: eyeSize * 0.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Occhio destro
          Positioned(
            right: size.width / 2 - 80,
            child: Opacity(
              opacity: eyeOpacity,
              child: Container(
                width: eyeSize,
                height: eyeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VexonColors.brandRed,
                  boxShadow: [
                    BoxShadow(
                      color: VexonColors.brandRed.withOpacity(0.8),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: eyeSize * 0.4,
                    height: eyeSize * 0.4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4 creature che convergono VIOLENTEMENTE
  Widget _buildCreatures(double t, Size size) {
    // Movimento aggressivo: ease-in (parte lenta, finisce veloce/violento)
    final easeMovement = Curves.easeIn.transform(t);

    // Sussulti: vibrazione nel movimento
    final jitter = sin(t * 300) * 0.1; // Tremolo rapido

    final corners = [
      {'start': Offset(-200, -200), 'name': 'topLeft'},
      {'start': Offset(size.width + 200, -200), 'name': 'topRight'},
      {'start': Offset(-200, size.height + 200), 'name': 'bottomLeft'},
      {'start': Offset(size.width + 200, size.height + 200), 'name': 'bottomRight'},
    ];

    return Stack(
      children: corners.map((corner) {
        final startOffset = corner['start'] as Offset;
        final centerOffset =
            Offset(size.width / 2, size.height / 2);

        // Movimento con sussulti
        final movementT = (easeMovement + jitter).clamp(0.0, 1.0);
        final currentPos = Offset(
          startOffset.dx + (centerOffset.dx - startOffset.dx) * movementT,
          startOffset.dy + (centerOffset.dy - startOffset.dy) * movementT,
        );

        // Opacità cresce mentre si avvicina
        final moveOpacity = (movementT * 0.9).clamp(0.0, 0.9);

        // Scale aggressivo: più grande mentre si avvicina
        final scale = 0.8 + movementT * 1.2;

        return Positioned(
          left: currentPos.dx - 60,
          top: currentPos.dy - 60,
          child: Opacity(
            opacity: moveOpacity,
            child: Transform.scale(
              scale: scale,
              child: _shadowCreatureAggressive(),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Ombra creatura aggressiva: più grande, più luminosa, più minacciosa
  Widget _shadowCreatureAggressive() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            VexonColors.brandRed.withOpacity(0.8),
            VexonColors.brandRed.withOpacity(0.5),
            Colors.black.withOpacity(0.2),
          ],
          stops: const [0.1, 0.4, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: VexonColors.brandRed.withOpacity(0.7),
            blurRadius: 60,
            spreadRadius: 20,
          ),
          BoxShadow(
            color: VexonColors.brandRed.withOpacity(0.4),
            blurRadius: 80,
            spreadRadius: 30,
          ),
        ],
      ),
      child: Stack(
        children: List.generate(4, (i) {
          final angle = (i / 4) * 360;
          final rad = angle * 3.14159 / 180;
          final offsetX = 40 * cos(rad);
          final offsetY = 40 * sin(rad);
          return Positioned(
            left: 70 + offsetX - 20,
            top: 70 + offsetY - 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VexonColors.brandRed.withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: VexonColors.brandRed.withOpacity(0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Fase finale: un breve impatto rosso "innesca" la frattura, poi le
  /// crepe si propagano dal centro nel buio (niente pagina bianca — il
  /// buio profondo resta protagonista), e infine il logo emerge
  /// attraverso di esse. Il logo compare UNA SOLA VOLTA qui: SplashScreen
  /// subito dopo lo mostra già a piena opacità (`startVisible: true`),
  /// senza rifare da capo un fade-in che prima causava un effetto
  /// "compare, sparisce, ricompare" indesiderato.
  Widget _buildFinalPhase(double t, Size size) {
    // Impatto: lampo rosso rapido che si dissolve subito, come l'istante
    // in cui lo schermo "si rompe".
    final impact = t < 0.12 ? (1 - Curves.easeIn.transform(t / 0.12)) : 0.0;

    // Le crepe crescono da 0.05 a 0.55 del tempo di questa fase, poi
    // restano ferme, già formate, mentre il logo emerge.
    final crackT = Curves.easeOut.transform(((t - 0.05) / 0.5).clamp(0.0, 1.0));

    // Il logo emerge dopo che le crepe sono quasi complete.
    final logoT = Curves.easeOut.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));

    final crackScale = size.shortestSide * 0.9; // pixel per unità di raggio

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black), // buio profondo di base
        if (impact > 0)
          ColoredBox(color: VexonColors.brandRed.withOpacity(impact * 0.55)),
        CustomPaint(
          painter: _CrackPainter(
            branches: _crackBranches,
            branchDelays: _crackDelays,
            growth: crackT,
            scale: crackScale,
          ),
        ),
        Center(
          child: Opacity(
            opacity: logoT,
            child: Transform.scale(
              scale: 0.85 + logoT * 0.15,
              child: Image.asset('assets/icons/logo_splash.png', width: 260),
            ),
          ),
        ),
      ],
    );
  }
}

/// Disegna le crepe che si propagano dal centro verso l'esterno, come
/// vetro che si rompe. [growth] (0-1) controlla quanta parte di ognuna è
/// già stata disegnata, usando `PathMetrics` per un'estensione fluida
/// della linea invece di farla comparire di scatto per intero.
class _CrackPainter extends CustomPainter {
  final List<List<Offset>> branches;
  final List<double> branchDelays;
  final double growth;
  final double scale;

  _CrackPainter({
    required this.branches,
    required this.branchDelays,
    required this.growth,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < branches.length; i++) {
      final delay = branchDelays[i];
      final localGrowth = ((growth - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (localGrowth <= 0) continue;

      final points = branches[i];
      final path = Path()
        ..moveTo(center.dx + points[0].dx * scale, center.dy + points[0].dy * scale);
      for (final p in points.skip(1)) {
        path.lineTo(center.dx + p.dx * scale, center.dy + p.dy * scale);
      }

      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) continue;
      final totalLength = metrics.fold<double>(0, (sum, m) => sum + m.length);
      final targetLength = totalLength * localGrowth;

      var drawn = 0.0;
      for (final metric in metrics) {
        if (drawn >= targetLength) break;
        final remaining = targetLength - drawn;
        final extractLength = remaining < metric.length ? remaining : metric.length;
        final partial = metric.extractPath(0, extractLength);

        // Bagliore rosso dietro la crepa...
        final glowPaint = Paint()
          ..color = VexonColors.brandRed.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawPath(partial, glowPaint);

        // ...più una linea chiara e nitida sopra, per il taglio vero e proprio.
        final linePaint = Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(partial, linePaint);

        drawn += metric.length;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter oldDelegate) => true;
}
