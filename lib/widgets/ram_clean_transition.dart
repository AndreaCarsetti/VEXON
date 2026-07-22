import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';
import '../services/ram_cleaner_service.dart';

/// Risultato di una pulizia RAM, con lo snapshot prima/dopo letto dal
/// monitor hardware già presente in VEXON — è un numero reale, non stimato
/// dallo script di pulizia stesso.
class RamCleanResult {
  final double ramBeforeGb;
  final double ramAfterGb;
  final double ramTotalGb;
  final int processesTrimmed;

  const RamCleanResult({
    required this.ramBeforeGb,
    required this.ramAfterGb,
    required this.ramTotalGb,
    required this.processesTrimmed,
  });

  double get freedGb => (ramBeforeGb - ramAfterGb).clamp(0, ramTotalGb);
}

/// Overlay mostrato durante e dopo la pulizia RAM ([RamCleanerService]).
///
/// Due fasi:
/// 1. **Pulizia in corso** (durata reale non prevedibile): una "griglia di
///    memoria" — blocchi che si accendono e si spengono, attraversati in
///    loop da un'onda diagonale — più un'icona centrale con alone
///    pulsante. Nessuna barra di progresso finta: è un loop indeterminato
///    onesto.
/// 2. **Risultato** (appena il [RamCleanerService.clean] reale completa):
///    onde d'urto che si espandono, una raffica di scintille, e i numeri
///    prima/dopo che si animano contando invece di comparire di scatto.
///
/// Si rimuove da sola tramite [onCompleted]. Non blocca l'interazione con
/// l'app sotto (`IgnorePointer`).
class RamCleanTransition extends StatefulWidget {
  final Future<RamCleanResult> resultFuture;
  final VoidCallback onCompleted;

  const RamCleanTransition({
    super.key,
    required this.resultFuture,
    required this.onCompleted,
  });

  @override
  State<RamCleanTransition> createState() => _RamCleanTransitionState();
}

class _RamCleanTransitionState extends State<RamCleanTransition>
    with TickerProviderStateMixin {
  late final AnimationController _loopController;
  late final AnimationController _resultController;
  late final List<_GridBlock> _blocks;
  late final List<_Ember> _embers;
  RamCleanResult? _result;

  static const _gridCols = 14;
  static const _gridRows = 6;

  @override
  void initState() {
    super.initState();

    final rnd = Random();
    _blocks = List.generate(
      _gridCols * _gridRows,
      (i) => _GridBlock(
        col: i % _gridCols,
        row: i ~/ _gridCols,
        phaseOffset: rnd.nextDouble() * 2 * pi,
        flicker: 0.5 + rnd.nextDouble() * 0.5,
      ),
    );
    _embers = List.generate(14, (_) => _Ember.random(rnd));

    // Durata scelta apposta perché la frequenza dello shimmer di base (3
    // cicli, vedi _GridBlock) completi un numero intero di cicli in questo
    // arco di tempo: il loop si richiude senza scatti visibili.
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    widget.resultFuture.then((result) {
      if (!mounted) return;
      _loopController.stop();
      setState(() => _result = result);
      _resultController.forward().whenComplete(widget.onCompleted);
    });
  }

  @override
  void dispose() {
    _loopController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  double _interval(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.90)),
          ),
          if (_result != null) ..._buildShockRings(_result!),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 460,
                height: 200,
                child: _result == null ? _buildGridField() : _buildBurstField(),
              ),
              const SizedBox(height: 8),
              _result == null ? _buildCleaningLabel() : _buildResultCard(_result!),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Fase 1: griglia di memoria + icona centrale
  // ---------------------------------------------------------------------

  Widget _buildGridField() {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        final t = _loopController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(460, 200),
              painter: _MemoryGridPainter(blocks: _blocks, t: t, cols: _gridCols, rows: _gridRows),
            ),
            CustomPaint(
              size: const Size(460, 200),
              painter: _EmberFieldPainter(embers: _embers, t: t),
            ),
            _buildCenterIcon(t),
          ],
        );
      },
    );
  }

  Widget _buildCenterIcon(double t) {
    final pulse = 0.92 + 0.08 * (1 - (2 * t - 1).abs());
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Alone sfumato dietro l'icona, respira leggermente con lo stesso
          // ritmo dell'icona per dare un senso di "energia" concentrata.
          Container(
            width: 108 * pulse,
            height: 108 * pulse,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  VexonColors.brandRed.withOpacity(0.35),
                  VexonColors.brandRed.withOpacity(0.0),
                ],
              ),
            ),
          ),
          Transform.rotate(
            angle: t * 2 * pi,
            child: CustomPaint(
              size: const Size(92, 92),
              painter: _ScanRingPainter(color: VexonColors.brandRed, t: t),
            ),
          ),
          Transform.scale(
            scale: pulse,
            child: const Icon(Icons.cleaning_services, size: 38, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCleaningLabel() {
    return const Text(
      'PULIZIA RAM IN CORSO…',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 3,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Fase 2: risultato — onde d'urto, raffica di scintille, numeri animati
  // ---------------------------------------------------------------------

  List<Widget> _buildShockRings(RamCleanResult result) {
    return [
      AnimatedBuilder(
        animation: _resultController,
        builder: (context, _) {
          final t = _resultController.value;
          return Stack(
            children: List.generate(4, (i) {
              final delay = i * 0.08;
              final localT = _interval(t, delay, delay + 0.55).clamp(0.0, 1.0);
              if (localT <= 0 || localT >= 1) return const SizedBox.shrink();
              final radius = Curves.easeOut.transform(localT) * 320;
              final opacity = (1 - localT) * 0.55;
              return Center(
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: VexonColors.success.withOpacity(opacity),
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    ];
  }

  Widget _buildBurstField() {
    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, _) {
        final t = _resultController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(460, 200),
              painter: _BurstParticlesPainter(seed: _blocks.length, t: t),
            ),
            _buildResultIcon(t),
          ],
        );
      },
    );
  }

  Widget _buildResultIcon(double t) {
    final pop = Curves.elasticOut.transform(_interval(t, 0.0, 0.45).clamp(0.0, 1.0));
    final fadeOut = 1 - Curves.easeIn.transform(_interval(t, 0.82, 1.0));

    return Opacity(
      opacity: fadeOut,
      child: Transform.scale(
        scale: 0.5 + pop.clamp(0.0, 1.25) * 0.5,
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                VexonColors.success.withOpacity(0.35),
                VexonColors.success.withOpacity(0.0),
              ],
            ),
          ),
          child: const Icon(Icons.check_circle, size: 60, color: VexonColors.success),
        ),
      ),
    );
  }

  Widget _buildResultCard(RamCleanResult result) {
    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, _) {
        final t = _resultController.value;
        final slide = 1 - Curves.easeOut.transform(_interval(t, 0.15, 0.55).clamp(0.0, 1.0));
        final fadeIn = Curves.easeOut.transform(_interval(t, 0.15, 0.5).clamp(0.0, 1.0));
        final fadeOut = 1 - Curves.easeIn.transform(_interval(t, 0.82, 1.0));
        final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);

        // I numeri contano dal valore "prima" al valore "dopo" invece di
        // comparire già risolti — piccolo dettaglio che dà più la
        // sensazione di un'azione realmente avvenuta.
        final countProgress = Curves.easeOut.transform(_interval(t, 0.2, 0.7).clamp(0.0, 1.0));
        final animatedRam = result.ramBeforeGb -
            (result.ramBeforeGb - result.ramAfterGb) * countProgress;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slide * 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'RAM OTTIMIZZATA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${animatedRam.toStringAsFixed(1)} GB',
                  style: const TextStyle(
                    color: VexonColors.success,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'partito da ${result.ramBeforeGb.toStringAsFixed(1)} GB su ${result.ramTotalGb.toStringAsFixed(0)} GB totali',
                  style: const TextStyle(color: VexonColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  result.freedGb > 0.05
                      ? '-${result.freedGb.toStringAsFixed(1)} GB · ${result.processesTrimmed} processi ottimizzati'
                      : '${result.processesTrimmed} processi ottimizzati',
                  style: const TextStyle(
                    color: VexonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Blocchi della griglia di memoria
// ---------------------------------------------------------------------

class _GridBlock {
  final int col;
  final int row;
  final double phaseOffset;
  final double flicker;

  const _GridBlock({
    required this.col,
    required this.row,
    required this.phaseOffset,
    required this.flicker,
  });
}

/// Disegna la griglia: ogni blocco ha uno shimmer di base (oscillazione
/// dolce, 3 cicli completi per ogni giro del loop — così il loop si
/// richiude senza scatti) più un'onda diagonale che lo attraversa una
/// volta per giro, illuminandolo di più al passaggio.
class _MemoryGridPainter extends CustomPainter {
  final List<_GridBlock> blocks;
  final double t;
  final int cols;
  final int rows;

  _MemoryGridPainter({required this.blocks, required this.t, required this.cols, required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 5.0;
    final blockW = (size.width - gap * (cols - 1)) / cols;
    final blockH = (size.height - gap * (rows - 1)) / rows;

    for (final b in blocks) {
      // Shimmer di base: 3 cicli interi in t∈[0,1] → nessuno scatto al loop.
      final shimmer = 0.5 + 0.5 * sin(2 * pi * (3 * t) + b.phaseOffset);

      // Onda diagonale: posizione normalizzata del blocco lungo la
      // diagonale, confrontata con l'avanzamento dell'onda in questo giro.
      final diagPos = (b.col / cols + b.row / rows) / 2;
      final wave = exp(-pow((diagPos - t) * 3.2, 2)) * 0.9;

      final brightness = (shimmer * b.flicker * 0.35 + wave).clamp(0.0, 1.0);
      if (brightness < 0.03) continue;

      final rect = Rect.fromLTWH(
        b.col * (blockW + gap),
        b.row * (blockH + gap),
        blockW,
        blockH,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));

      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(brightness * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawRRect(rrect, glowPaint);

      final corePaint = Paint()..color = Colors.white.withOpacity(brightness * 0.25);
      canvas.drawRRect(rrect.deflate(1), corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MemoryGridPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------
// Scintille ambientali (stesso linguaggio visivo di ParticleBackground)
// ---------------------------------------------------------------------

class _Ember {
  final double startX;
  final double startY;
  final double speed;
  final double radius;
  final double phaseOffset;

  const _Ember({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.radius,
    required this.phaseOffset,
  });

  factory _Ember.random(Random rnd) {
    return _Ember(
      startX: rnd.nextDouble(),
      startY: rnd.nextDouble(),
      speed: 0.15 + rnd.nextDouble() * 0.25,
      radius: 1.4 + rnd.nextDouble() * 2.2,
      phaseOffset: rnd.nextDouble() * 2 * pi,
    );
  }
}

class _EmberFieldPainter extends CustomPainter {
  final List<_Ember> embers;
  final double t;

  _EmberFieldPainter({required this.embers, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    const emberCore = Color(0xFFFFA552);

    for (final e in embers) {
      final progress = (e.startY - e.speed * t) % 1.0;
      final y = progress < 0 ? progress + 1.0 : progress;
      final x = e.startX;

      final fade = sin(pi * y).clamp(0.0, 1.0); // debole ai bordi, piena al centro verticale
      final center = Offset(x * size.width, y * size.height);

      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(fade * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(center, e.radius * 2, glowPaint);

      final corePaint = Paint()..color = emberCore.withOpacity(fade * 0.8);
      canvas.drawCircle(center, e.radius * 0.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberFieldPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------
// Anello rotante attorno all'icona centrale
// ---------------------------------------------------------------------

class _ScanRingPainter extends CustomPainter {
  final Color color;
  final double t;
  const _ScanRingPainter({required this.color, required this.t});

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
  bool shouldRepaint(covariant _ScanRingPainter oldDelegate) => oldDelegate.t != t;
}

// ---------------------------------------------------------------------
// Raffica di scintille alla rivelazione del risultato
// ---------------------------------------------------------------------

class _BurstParticlesPainter extends CustomPainter {
  final int seed;
  final double t;

  _BurstParticlesPainter({required this.seed, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed); // seme fisso: stessa raffica ad ogni frame, solo t cambia
    final center = Offset(size.width / 2, size.height / 2 - 20);
    const emberCore = Color(0xFFFFA552);

    for (var i = 0; i < 26; i++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final speed = 60 + rnd.nextDouble() * 140;
      final startDelay = rnd.nextDouble() * 0.15;
      final localT = ((t - startDelay) / (1 - startDelay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final eased = Curves.easeOut.transform(localT);
      final distance = eased * speed;
      final opacity = (1 - localT);

      final pos = center + Offset(cos(angle), sin(angle)) * distance;
      final radius = 2.0 + rnd.nextDouble() * 2.0;

      final glowPaint = Paint()
        ..color = VexonColors.success.withOpacity(opacity * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(pos, radius * 2, glowPaint);

      final corePaint = Paint()..color = emberCore.withOpacity(opacity * 0.85);
      canvas.drawCircle(pos, radius * 0.6, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstParticlesPainter oldDelegate) => true;
}
