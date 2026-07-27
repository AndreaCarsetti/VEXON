import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';

/// Angoli da mirino riutilizzabili in stile HUD — lo stesso linguaggio
/// visivo del pannello hardware, applicabile a qualunque elemento della UI
/// (card, campi di ricerca, barra superiore...) per dare coerenza
/// "centro di controllo" a tutta la pagina.
///
/// Volutamente NON animato: va bene per il pannello hardware (uno solo,
/// sempre visibile) avere rotazioni/scanline continue, ma applicare lo
/// stesso trattamento animato a decine di card nella griglia dei giochi
/// appesantirebbe inutilmente il rendering. Qui ci si limita a un
/// overlay statico, attivabile/disattivabile (es. su hover).
///
/// Va inserito dentro uno Stack, tipicamente con `Positioned.fill`.
class HudCornerBrackets extends StatelessWidget {
  final double length;
  final double thickness;
  final Color color;

  const HudCornerBrackets({
    super.key,
    this.length = 10,
    this.thickness = 1.4,
    this.color = VexonColors.brandRed,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BracketsPainter(length: length, thickness: thickness, color: color),
      ),
    );
  }
}

class _BracketsPainter extends CustomPainter {
  final double length;
  final double thickness;
  final Color color;

  _BracketsPainter({required this.length, required this.thickness, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    void corner(Offset origin, Offset armX, Offset armY) {
      canvas.drawLine(origin, origin + armX, paint);
      canvas.drawLine(origin, origin + armY, paint);
    }

    corner(const Offset(0, 0), Offset(length, 0), Offset(0, length));
    corner(Offset(size.width, 0), Offset(-length, 0), Offset(0, length));
    corner(Offset(0, size.height), Offset(length, 0), Offset(0, -length));
    corner(Offset(size.width, size.height), Offset(-length, 0), Offset(0, -length));
  }

  @override
  bool shouldRepaint(covariant _BracketsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.length != length || oldDelegate.thickness != thickness;
}
