import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';
import 'home_screen.dart';

/// Splash screen "software" mostrata come prima schermata dell'app.
///
/// Perché non uno splash nativo: flutter_native_splash non supporta Windows
/// (solo Android/iOS/Web). Su desktop l'istante prima che Flutter carichi è
/// comunque molto breve, quindi gestire tutta l'animazione qui è sufficiente
/// a dare la sensazione di un avvio "brandizzato" senza codice nativo Win32.
///
/// Sequenza normale: fade-in (900ms) → resta visibile (2200ms) → fade-out
/// (700ms) → passa alla home. Durata totale ~3.8s.
///
/// Se [startVisible] è true (usato da `BootSequenceScreen`, dove il logo è
/// già apparso attraverso l'effetto delle crepe), il fade-in viene saltato:
/// il logo parte già a piena opacità, resta visibile, poi sfuma normalmente
/// verso la home. Altrimenti si vedrebbe il logo apparire nel boot,
/// sparire di scatto, e ricomparire qui con un secondo fade-in — un
/// effetto "doppio" indesiderato.
class SplashScreen extends StatefulWidget {
  final bool startVisible;
  const SplashScreen({super.key, this.startVisible = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2200);
  static const _fadeOutDuration = Duration(milliseconds: 700);

  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    // Se il logo è già visibile (arrivo dal boot con le crepe), niente
    // vero fade-in: usiamo una durata minima (1ms) invece di zero per
    // evitare un TweenSequenceItem con weight 0, che Flutter non accetta.
    final fadeInDuration =
        widget.startVisible ? const Duration(milliseconds: 1) : const Duration(milliseconds: 900);

    _controller = AnimationController(
      vsync: this,
      duration: fadeInDuration + _holdDuration + _fadeOutDuration,
    );

    final total = _controller.duration!.inMilliseconds;
    final fadeInEnd = fadeInDuration.inMilliseconds / total;
    final fadeOutStart =
        (fadeInDuration.inMilliseconds + _holdDuration.inMilliseconds) / total;

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: fadeInEnd),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.0), weight: fadeOutStart - fadeInEnd),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1 - fadeOutStart),
    ]).animate(_controller);

    // IMPORTANTE: su Windows la finestra nativa diventa visibile prima che
    // Flutter disegni il primo frame. Se l'animazione partisse subito in
    // initState, il tempo "morto" tra la creazione della finestra e il
    // primo frame reale verrebbe consumato dal timer dell'animazione,
    // facendo apparire il logo già parzialmente/totalmente opaco al primo
    // frame visibile. Aspettiamo il primo frame effettivamente disegnato
    // prima di far partire il fade-in, così l'utente lo vede per intero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward().whenComplete(_goToHome);
    });
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        // Fade pulito invece dello slide-up di default di MaterialPageRoute:
        // lo splash è già a opacità 0 quando arriviamo qui, quindi un fade
        // sulla nuova schermata basta per un passaggio impercettibile,
        // invece di un movimento che distrarrebbe dall'effetto già fatto.
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VexonColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Image.asset('assets/icons/logo_splash.png', width: 320),
        ),
      ),
    );
  }
}
