import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';
import '../services/horror_audio_service.dart';
import 'splash_screen.dart';

/// Sequenza di avvio HORROR INTENSE: 2 occhi rossi che si aprono nel buio,
/// poi 4 creature ombra dai 4 angoli che convergono VIOLENTEMENTE verso il
/// centro con sussulti e lampi rossi, prima di una dissolvenza violenta che
/// rivela il logo VEXON in un bagliore bianco.
/// 
/// Fase 1 (0-0.15): Occhi che si aprono lentamente dal nero
/// Fase 2 (0.15-0.55): Creature convergono con movimento aggressivo e sussulti,
///                      lampi rossi random
/// Fase 3 (0.55-0.75): Creature si contraggono verso il centro, lampi intensi
/// Fase 4 (0.75-1.0): Dissolvenza violenta bianca + logo emerge
class BootSequenceScreen extends StatefulWidget {
  const BootSequenceScreen({super.key});

  @override
  State<BootSequenceScreen> createState() => _BootSequenceScreenState();
}

class _BootSequenceScreenState extends State<BootSequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<double> _flashTimes;

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
        pageBuilder: (_, __, ___) => const SplashScreen(),
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

  /// Fase finale: dissolvenza bianca violenta + logo emerge
  Widget _buildFinalPhase(double t, Size size) {
    final whiteFlash = Curves.easeOut.transform(t);
    final logoOpacity = Curves.easeOut.transform((t - 0.2).clamp(0.0, 1.0));
    final logoScale =
        0.6 + 0.4 * Curves.easeOut.transform((t - 0.2).clamp(0.0, 1.0));

    return Stack(
      children: [
        // Flash bianco aggressivo
        ColoredBox(
          color: Colors.white.withOpacity(whiteFlash * 0.9),
        ),

        // Logo emerge dal bagliore
        Center(
          child: Opacity(
            opacity: logoOpacity,
            child: Transform.scale(
              scale: logoScale,
              child: Image.asset(
                'assets/icons/logo_splash.png',
                width: 260,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
