import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';

/// Loader con il simbolo VEXON che pulsa (scala + opacità), usato al posto
/// di un generico `CircularProgressIndicator` — piccolo dettaglio, ma è
/// esattamente il tipo di rifinitura che distingue un'app curata da una
/// "fatta con i widget di default".
class VexonLoadingIndicator extends StatefulWidget {
  final String? label;
  const VexonLoadingIndicator({super.key, this.label});

  @override
  State<VexonLoadingIndicator> createState() => _VexonLoadingIndicatorState();
}

class _VexonLoadingIndicatorState extends State<VexonLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              final scale = 0.88 + t * 0.12;
              final opacity = 0.5 + t * 0.5;
              return Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Image.asset('assets/icons/symbol.png', width: 48),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.label!,
              style: const TextStyle(color: VexonColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
