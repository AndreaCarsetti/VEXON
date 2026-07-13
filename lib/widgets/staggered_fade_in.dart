import 'package:flutter/material.dart';

/// Anima l'ingresso di un elemento con fade + leggero slide dal basso,
/// con un ritardo proporzionale a [index] — dà l'effetto "a cascata"
/// quando la griglia dei giochi compare per la prima volta, invece che
/// tutti gli elementi che compaiono di scatto insieme.
///
/// Il ritardo è limitato (vedi [_maxDelay]) così anche con librerie molto
/// grandi l'ultima card non aspetta secondi interi prima di comparire.
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredFadeIn({super.key, required this.index, required this.child});

  static const _maxDelay = Duration(milliseconds: 400);
  static const _perItemDelay = Duration(milliseconds: 30);
  static const _duration = Duration(milliseconds: 350);

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: StaggeredFadeIn._duration);

    final delayMs = (widget.index * StaggeredFadeIn._perItemDelay.inMilliseconds)
        .clamp(0, StaggeredFadeIn._maxDelay.inMilliseconds);

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
