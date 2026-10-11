import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';

/// Linea divisoria con un "cometa" luminosa che la percorre in loop —
/// pensata per separare sezioni della pagina (es. sotto la barra
/// superiore) con lo stesso linguaggio "centro di controllo" del pannello
/// hardware, invece di un semplice bordo statico.
class ScanDivider extends StatefulWidget {
  final Color color;
  final double thickness;
  final Duration duration;
  final bool reverse;

  const ScanDivider({
    super.key,
    this.color = VexonColors.brandRed,
    this.thickness = 2,
    this.duration = const Duration(seconds: 3),
    this.reverse = false,
  });

  @override
  State<ScanDivider> createState() => _ScanDividerState();
}

class _ScanDividerState extends State<ScanDivider> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const segmentWidth = 160.0;

    return SizedBox(
      height: widget.thickness,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Entra da un lato (fuori schermo) ed esce dall'altro: a
              // t=0 e t=1 la cometa è completamente invisibile, quindi il
              // loop riparte senza scatti percepibili. Con [reverse] va da
              // destra a sinistra invece che da sinistra a destra — utile
              // per far "contrastare" due ScanDivider sovrapposti (es.
              // sopra/sotto lo schermo) invece di viaggiare nello stesso
              // verso.
              final progress = widget.reverse ? 1 - _controller.value : _controller.value;
              final left = progress * (width + segmentWidth) - segmentWidth;

              return ClipRect(
                child: Stack(
                  children: [
                    Container(color: Colors.white10, height: widget.thickness),
                    Positioned(
                      left: left,
                      width: segmentWidth,
                      height: widget.thickness,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withOpacity(0.0),
                              widget.color,
                              widget.color.withOpacity(0.0),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(color: widget.color.withOpacity(0.7), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
