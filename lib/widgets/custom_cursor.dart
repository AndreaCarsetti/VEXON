import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/vexon_colors.dart';

/// Cursore personalizzato per tutta l'app: nasconde il cursore di sistema
/// e ne disegna uno su misura — una punta angolare a forma di "V" (coerente
/// col logo VEXON), con bagliore rosso e una breve scia di scintille
/// ambra che segue il movimento del mouse.
///
/// Va avvolto attorno al contenuto principale dell'app (in `main.dart`,
/// dentro il `builder` di `MaterialApp`, così copre ogni schermata).
class CustomCursor extends StatefulWidget {
  final Widget child;
  const CustomCursor({super.key, required this.child});

  @override
  State<CustomCursor> createState() => _CustomCursorState();
}

class _TrailPoint {
  Offset position;
  double age; // 0 = appena creato, 1 = da rimuovere
  _TrailPoint(this.position, this.age);
}

class _CustomCursorState extends State<CustomCursor> with SingleTickerProviderStateMixin {
  Offset? _position;
  final List<_TrailPoint> _trail = [];
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;
    if (_trail.isEmpty) return;

    setState(() {
      // Ogni punto della scia invecchia nel tempo e sparisce gradualmente.
      for (final point in _trail) {
        point.age += dt * 2.2; // velocità di dissolvenza della scia
      }
      _trail.removeWhere((p) => p.age >= 1.0);
    });
  }

  void _updatePosition(Offset position) {
    setState(() {
      _position = position;
      // Aggiunge un nuovo punto alla scia solo se ci si è mossi abbastanza
      // dall'ultimo, per non affollarla con punti troppo ravvicinati.
      if (_trail.isEmpty || (_trail.last.position - position).distance > 6) {
        _trail.add(_TrailPoint(position, 0.0));
        if (_trail.length > 14) _trail.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.none, // nasconde il cursore di sistema
      onHover: (event) => _updatePosition(event.position),
      child: Listener(
        onPointerMove: (event) => _updatePosition(event.position),
        child: Stack(
          children: [
            widget.child,
            if (_position != null)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _CursorPainter(position: _position!, trail: _trail),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final Offset position;
  final List<_TrailPoint> trail;

  _CursorPainter({required this.position, required this.trail});

  static const _emberCore = Color(0xFFFFA552);

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrail(canvas);
    _paintCursor(canvas);
  }

  void _paintTrail(Canvas canvas) {
    for (final point in trail) {
      final opacity = (1.0 - point.age).clamp(0.0, 1.0) * 0.5;
      if (opacity <= 0) continue;

      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(opacity * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(point.position, 5 * (1 - point.age * 0.5), glowPaint);

      final corePaint = Paint()..color = _emberCore.withOpacity(opacity * 0.8);
      canvas.drawCircle(point.position, 2 * (1 - point.age * 0.5), corePaint);
    }
  }

  /// Disegna un mirino/crosshair stile FPS: quattro tratti brevi attorno
  /// al punto attivo (con un piccolo spazio vuoto al centro, come nei
  /// giochi sparatutto), più un puntino centrale nitido per il riferimento
  /// preciso di dove "clicchi" davvero.
  void _paintCursor(Canvas canvas) {
    const gap = 5.0; // spazio vuoto centrale
    const armLength = 7.0; // lunghezza di ogni tratto

    final lines = <Offset, Offset>{
      // sopra
      position.translate(0, -gap - armLength): position.translate(0, -gap),
      // sotto
      position.translate(0, gap): position.translate(0, gap + armLength),
      // sinistra
      position.translate(-gap - armLength, 0): position.translate(-gap, 0),
      // destra
      position.translate(gap, 0): position.translate(gap + armLength, 0),
    };

    // Bagliore dietro i tratti
    final glowPaint = Paint()
      ..color = VexonColors.brandRed.withOpacity(0.55)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    for (final entry in lines.entries) {
      canvas.drawLine(entry.key, entry.value, glowPaint);
    }

    // Tratti nitidi sopra il bagliore
    final linePaint = Paint()
      ..color = VexonColors.brandRed
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final entry in lines.entries) {
      canvas.drawLine(entry.key, entry.value, linePaint);
    }

    // Anellino sottile attorno al centro, per un tocco "mirino da gioco"
    final ringPaint = Paint()
      ..color = VexonColors.brandRed.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(position, gap + 1.5, ringPaint);

    // Punto attivo centrale in ambra, per riferimento preciso.
    canvas.drawCircle(position, 1.6, Paint()..color = _emberCore);
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) => true;
}
