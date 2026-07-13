import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/kiosk_service.dart';
import '../theme/vexon_colors.dart';

/// Avvolge l'intera app e ascolta globalmente il tasto ESC.
/// Se tenuto premuto per [holdDuration], esce dalla modalità kiosk.
///
/// Il rilascio anticipato annulla l'operazione — evita uscite accidentali
/// per una pressione rapida di ESC (es. per chiudere un dialog).
class KioskExitGuard extends StatefulWidget {
  final Widget child;
  final Duration holdDuration;

  const KioskExitGuard({
    super.key,
    required this.child,
    this.holdDuration = const Duration(seconds: 2),
  });

  @override
  State<KioskExitGuard> createState() => _KioskExitGuardState();
}

class _KioskExitGuardState extends State<KioskExitGuard> {
  Timer? _ticker;
  double _progress = 0;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _ticker?.cancel();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;

    if (event is KeyDownEvent && !_holding) {
      _startHold();
    } else if (event is KeyUpEvent) {
      _cancelHold();
    }
    // Non consumiamo l'evento: ESC può ancora essere usato per altro
    // (es. chiudere dialog) mentre teniamo traccia della pressione lunga.
    return false;
  }

  void _startHold() {
    _holding = true;
    _progress = 0;
    const tickInterval = Duration(milliseconds: 30);
    final totalTicks = widget.holdDuration.inMilliseconds / tickInterval.inMilliseconds;
    var tick = 0;

    _ticker = Timer.periodic(tickInterval, (timer) {
      tick++;
      setState(() => _progress = (tick / totalTicks).clamp(0, 1));
      if (_progress >= 1) {
        timer.cancel();
        _holding = false;
        _executeExit();
      }
    });
  }

  void _cancelHold() {
    _ticker?.cancel();
    _holding = false;
    if (mounted) setState(() => _progress = 0);
  }

  Future<void> _executeExit() async {
    await KioskService.exitKiosk();
    if (mounted) setState(() => _progress = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_progress > 0)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _ExitProgressIndicator(progress: _progress),
            ),
          ),
      ],
    );
  }
}

class _ExitProgressIndicator extends StatelessWidget {
  final double progress;
  const _ExitProgressIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: VexonColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VexonColors.brandRed.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: VexonColors.brandRed.withOpacity(0.3), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(VexonColors.brandRed),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Uscita dalla modalità kiosk…',
            style: TextStyle(
              color: VexonColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
