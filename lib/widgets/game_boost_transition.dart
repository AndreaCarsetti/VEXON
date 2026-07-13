import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';

/// Overlay animato mostrato brevemente (circa 1.6s) quando il Game Boost
/// viene attivato o disattivato, poi si rimuove da solo tramite
/// [onCompleted]. Non blocca l'interazione con l'app sotto (`IgnorePointer`).
///
/// Sequenza: sfondo che si scurisce + 3 anelli rossi che si espandono dal
/// centro con partenza scaglionata + icona/testo che compaiono con un
/// leggero "rimbalzo" (curva elastica) — poi tutto sfuma via.
class GameBoostTransition extends StatefulWidget {
  final bool activating; // true = attivazione, false = disattivazione
  final VoidCallback onCompleted;

  const GameBoostTransition({
    super.key,
    required this.activating,
    required this.onCompleted,
  });

  @override
  State<GameBoostTransition> createState() => _GameBoostTransitionState();
}

class _GameBoostTransitionState extends State<GameBoostTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _controller.forward().whenComplete(widget.onCompleted);
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
    final color = widget.activating ? VexonColors.brandRed : VexonColors.textSecondary;
    final label = widget.activating ? 'GAME BOOST ATTIVO' : 'GAME BOOST DISATTIVATO';

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          final fadeIn = Curves.easeOut.transform(_interval(t, 0.0, 0.15));
          final fadeOut = 1 - Curves.easeIn.transform(_interval(t, 0.75, 1.0));
          final envelope = (fadeIn * fadeOut).clamp(0.0, 1.0);

          final textGrow = Curves.elasticOut.transform(_interval(t, 0.05, 0.5));

          return Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(envelope * 0.88)),
              ),
              ..._buildRings(t, color),
              Center(
                child: Opacity(
                  opacity: envelope,
                  child: Transform.scale(
                    scale: 0.6 + textGrow.clamp(0.0, 1.2) * 0.4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 64, color: color),
                        const SizedBox(height: 12),
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 3 anelli concentrici che si espandono dal centro, con partenza
  /// scaglionata (ognuno inizia un po' dopo il precedente) per dare un
  /// effetto di "onda" invece che un singolo cerchio statico.
  List<Widget> _buildRings(double t, Color color) {
    return List.generate(3, (i) {
      final delay = i * 0.12;
      final localT = _interval(t, delay, delay + 0.5).clamp(0.0, 1.0);
      if (localT <= 0) return const SizedBox.shrink();

      final radius = localT * 260;
      final opacity = 1 - localT;

      return Center(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(opacity * 0.6), width: 2),
          ),
        ),
      );
    });
  }
}
