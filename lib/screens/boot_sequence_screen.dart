import 'dart:math';
import 'package:flutter/material.dart';
import '../services/horror_audio_service.dart';
import '../theme/vexon_colors.dart';
import 'home_screen.dart';

/// Sequenza di avvio "accensione": scintille ember (la stessa estetica già
/// usata in `particle_background.dart` e nel cursore personalizzato) che
/// partono dai bordi dello schermo e convergono verso il centro, andando a
/// formare il contorno della V del logo. Un lampo le "accende",
/// trasformandole nel logo vero e proprio, che resta fermo un momento e
/// poi sfuma verso la home.
///
/// A differenza dei tentativi precedenti (CRT, horror, terremoto, Matrix),
/// questa sequenza usa lo STESSO linguaggio visivo già presente nel resto
/// dell'app — niente estetica nuova introdotta apposta per il boot.
///
/// IMPORTANTE: tutta la sequenza — convergenza, accensione, attesa e
/// dissolvenza finale — vive in UN SOLO controller/widget, che alla fine
/// passa direttamente alla home. Prima passava per una `SplashScreen`
/// separata con un proprio controller: il cambio tra i due widget, anche
/// se pensato per essere impercettibile, poteva creare un frame in cui il
/// logo spariva di scatto e ricompariva. Con tutto in un'unica animazione
/// continua quel rischio sparisce alla radice.
///
/// Fase 1 (convergenza): le scintille convergono dai bordi verso il
///                       contorno della V
/// Fase 2 (accensione): lampo, dissolvenza incrociata verso il logo reale
/// Fase 3 (attesa): il logo resta fermo, fisso, senza bagliori pulsanti
/// Fase 4 (uscita): dissolvenza verso il nero, poi passa alla home
class BootSequenceScreen extends StatefulWidget {
  const BootSequenceScreen({super.key});

  @override
  State<BootSequenceScreen> createState() => _BootSequenceScreenState();
}

class _Ember {
  final Offset start; // coordinate relative allo schermo (0-1)
  final Offset target; // punto sul contorno della V, relativo al box del logo
  final double delay; // 0-1, ritardo di partenza entro la fase 1
  final double size;

  _Ember({
    required this.start,
    required this.target,
    required this.delay,
    required this.size,
  });
}

class _BootSequenceScreenState extends State<BootSequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;
  bool _soundPlayed = false;

  static const _totalDuration = Duration(milliseconds: 5200);
  static const _convergeEndMs = 2100;
  static const _igniteEndMs = 2550;
  static const _holdEndMs = 4550; // il logo resta fermo fino a qui
  // da _holdEndMs a fine (5200ms): dissolvenza verso il nero

  // Box (in px, relativo al centro schermo) dove si forma il contorno del
  // logo — proporzioni (0.97 circa, quasi quadrato) prese dal bounding box
  // reale di `assets/icons/symbol.png`, non inventate: altrimenti la forma
  // tracciata dalle scintille risulterebbe schiacciata o allargata rispetto
  // al logo vero che compare subito dopo.
  static const _vBoxWidth = 184.0;
  static const _vBoxHeight = 190.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    _generateEmbers();

    HorrorAudioService.initialize();
    _controller.addListener(_checkAudioCue);

    // Registrato SUBITO, in modo sincrono — su Windows la finestra diventa
    // visibile prima che Flutter disegni il primo frame; farlo dopo
    // un'attesa asincrona rischia di lasciare l'app ferma su schermo nero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward().whenComplete(_goToHome);
    });
  }

  void _generateEmbers() {
    final rnd = Random(33); // seed fisso: pattern coerente ad ogni avvio
    // .of(...) crea una copia modificabile: _generateVOutlinePoints()
    // ritorna una lista `const` (immutabile), e .shuffle() la modifica sul
    // posto — senza la copia si otterrebbe "Unsupported operation: Cannot
    // modify an unmodifiable list".
    final targets = List<Offset>.of(_generateVOutlinePoints())..shuffle(rnd);

    _embers = targets.map((target) {
      return _Ember(
        start: _randomEdgePoint(rnd),
        target: target,
        delay: rnd.nextDouble() * 0.28,
        size: 1.6 + rnd.nextDouble() * 2.6,
      );
    }).toList();
  }

  /// Punti campionati lungo il contorno REALE del logo (silhouette esterna
  /// di `assets/icons/symbol.png`, ali della lama comprese), in coordinate
  /// relative al box del logo (0,0 = angolo in alto a sinistra del box,
  /// 1,1 = in basso a destra).
  ///
  /// Non è una V generica disegnata a mano: sono 190 punti ricampionati a
  /// intervalli regolari lungo il perimetro reale della sagoma (estratta
  /// una volta sola con un contour-tracing offline sull'immagine sorgente),
  /// quindi le scintille disegnano davvero il profilo della lama — ali
  /// comprese — invece di una semplice V a due segmenti dritti.
  List<Offset> _generateVOutlinePoints() {
    return const [
      Offset(0.5015, 1.0000), Offset(0.4835, 0.9740), Offset(0.4875, 0.9569),
      Offset(0.4970, 0.9401), Offset(0.4875, 0.9133), Offset(0.4956, 0.9228),
      Offset(0.4978, 0.8974), Offset(0.4963, 0.8631), Offset(0.4845, 0.8330),
      Offset(0.4713, 0.8034), Offset(0.4592, 0.7733), Offset(0.4462, 0.7437),
      Offset(0.4323, 0.7144), Offset(0.4212, 0.6908), Offset(0.4073, 0.6615),
      Offset(0.3947, 0.6317), Offset(0.3814, 0.6021), Offset(0.3685, 0.5724),
      Offset(0.3555, 0.5427), Offset(0.3426, 0.5130), Offset(0.3284, 0.4838),
      Offset(0.3152, 0.4542), Offset(0.3017, 0.4248), Offset(0.2872, 0.3957),
      Offset(0.2739, 0.3661), Offset(0.2597, 0.3369), Offset(0.2447, 0.3081),
      Offset(0.2297, 0.2792), Offset(0.2150, 0.2502), Offset(0.2003, 0.2212),
      Offset(0.1959, 0.2186), Offset(0.2091, 0.2482), Offset(0.1949, 0.2255),
      Offset(0.1799, 0.1966), Offset(0.1551, 0.1725), Offset(0.1302, 0.1485),
      Offset(0.1079, 0.1225), Offset(0.0862, 0.0972), Offset(0.0633, 0.0715),
      Offset(0.0395, 0.0462), Offset(0.0279, 0.0377), Offset(0.0454, 0.0648),
      Offset(0.0623, 0.0826), Offset(0.0857, 0.1081), Offset(0.1059, 0.1349),
      Offset(0.1105, 0.1624), Offset(0.1163, 0.1914), Offset(0.1325, 0.2198),
      Offset(0.1473, 0.2488), Offset(0.1620, 0.2777), Offset(0.1767, 0.3067),
      Offset(0.1844, 0.3296), Offset(0.1705, 0.3004), Offset(0.1561, 0.2712),
      Offset(0.1404, 0.2426), Offset(0.1252, 0.2138), Offset(0.1090, 0.1855),
      Offset(0.0928, 0.1571), Offset(0.0761, 0.1289), Offset(0.0853, 0.1477),
      Offset(0.0993, 0.1770), Offset(0.1149, 0.2048), Offset(0.0964, 0.1943),
      Offset(0.0825, 0.1650), Offset(0.0677, 0.1360), Offset(0.0524, 0.1073),
      Offset(0.0383, 0.0780), Offset(0.0236, 0.0490), Offset(0.0094, 0.0198),
      Offset(0.0096, 0.0058), Offset(0.0372, 0.0254), Offset(0.0652, 0.0440),
      Offset(0.0938, 0.0614), Offset(0.1224, 0.0786), Offset(0.1505, 0.0971),
      Offset(0.1785, 0.1157), Offset(0.2062, 0.1351), Offset(0.2338, 0.1547),
      Offset(0.2614, 0.1743), Offset(0.2725, 0.2019), Offset(0.2842, 0.2309),
      Offset(0.3063, 0.2413), Offset(0.3071, 0.2614), Offset(0.3240, 0.2779),
      Offset(0.3142, 0.2469), Offset(0.3110, 0.2209), Offset(0.3299, 0.2466),
      Offset(0.3432, 0.2761), Offset(0.3569, 0.3055), Offset(0.3711, 0.3290),
      Offset(0.3896, 0.3429), Offset(0.4015, 0.3730), Offset(0.4243, 0.3937),
      Offset(0.4273, 0.4086), Offset(0.4426, 0.4301), Offset(0.4589, 0.4559),
      Offset(0.4698, 0.4836), Offset(0.5011, 0.4875), Offset(0.5315, 0.4765),
      Offset(0.5376, 0.4550), Offset(0.5395, 0.4443), Offset(0.5567, 0.4341),
      Offset(0.5770, 0.4082), Offset(0.5952, 0.3876), Offset(0.6068, 0.3574),
      Offset(0.6201, 0.3407), Offset(0.6372, 0.3141), Offset(0.6512, 0.2848),
      Offset(0.6642, 0.2552), Offset(0.6822, 0.2275), Offset(0.6848, 0.2436),
      Offset(0.6750, 0.2746), Offset(0.6829, 0.2769), Offset(0.7025, 0.2507),
      Offset(0.7200, 0.2237), Offset(0.7275, 0.1918), Offset(0.7482, 0.1678),
      Offset(0.7763, 0.1492), Offset(0.8041, 0.1300), Offset(0.8319, 0.1109),
      Offset(0.8599, 0.0923), Offset(0.8882, 0.0743), Offset(0.9164, 0.0561),
      Offset(0.9444, 0.0375), Offset(0.9725, 0.0189), Offset(1.0000, 0.0008),
      Offset(0.9867, 0.0304), Offset(0.9720, 0.0594), Offset(0.9573, 0.0883),
      Offset(0.9426, 0.1173), Offset(0.9279, 0.1463), Offset(0.9139, 0.1756),
      Offset(0.8989, 0.2045), Offset(0.8956, 0.1934), Offset(0.9102, 0.1643),
      Offset(0.9246, 0.1353), Offset(0.9293, 0.1216), Offset(0.9116, 0.1494),
      Offset(0.8955, 0.1778), Offset(0.8794, 0.2063), Offset(0.8645, 0.2352),
      Offset(0.8498, 0.2641), Offset(0.8351, 0.2931), Offset(0.8214, 0.3225),
      Offset(0.8218, 0.3132), Offset(0.8361, 0.2840), Offset(0.8511, 0.2552),
      Offset(0.8651, 0.2259), Offset(0.8811, 0.1974), Offset(0.8962, 0.1686),
      Offset(0.9106, 0.1403), Offset(0.8968, 0.1408), Offset(0.9019, 0.1244),
      Offset(0.9257, 0.0999), Offset(0.9455, 0.0738), Offset(0.9661, 0.0497),
      Offset(0.9675, 0.0394), Offset(0.9447, 0.0643), Offset(0.9224, 0.0903),
      Offset(0.8999, 0.1161), Offset(0.8767, 0.1417), Offset(0.8534, 0.1672),
      Offset(0.8275, 0.1909), Offset(0.8043, 0.2148), Offset(0.7903, 0.2441),
      Offset(0.7761, 0.2733), Offset(0.7603, 0.3018), Offset(0.7463, 0.3311),
      Offset(0.7305, 0.3596), Offset(0.7172, 0.3892), Offset(0.7033, 0.4185),
      Offset(0.6893, 0.4478), Offset(0.6760, 0.4773), Offset(0.6627, 0.5069),
      Offset(0.6495, 0.5365), Offset(0.6362, 0.5661), Offset(0.6230, 0.5956),
      Offset(0.6097, 0.6252), Offset(0.5965, 0.6548), Offset(0.5837, 0.6845),
      Offset(0.5700, 0.7127), Offset(0.5567, 0.7423), Offset(0.5434, 0.7719),
      Offset(0.5307, 0.8017), Offset(0.5178, 0.8314), Offset(0.5052, 0.8612),
      Offset(0.5037, 0.8955), Offset(0.5037, 0.9304), Offset(0.5070, 0.9618),
      Offset(0.5175, 0.9716),
    ];
  }

  /// Un punto casuale lungo il perimetro dello schermo (leggermente fuori
  /// dai bordi), in coordinate relative allo schermo intero.
  Offset _randomEdgePoint(Random rnd) {
    final side = rnd.nextInt(4);
    final t = rnd.nextDouble();
    switch (side) {
      case 0:
        return Offset(t, -0.06); // sopra
      case 1:
        return Offset(t, 1.06); // sotto
      case 2:
        return Offset(-0.06, t); // sinistra
      default:
        return Offset(1.06, t); // destra
    }
  }

  void _checkAudioCue() {
    final elapsedMs = _controller.value * _totalDuration.inMilliseconds;
    if (!_soundPlayed && elapsedMs >= _convergeEndMs) {
      _soundPlayed = true;
      HorrorAudioService.playLogoImpact();
    }
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const HomeScreen(),
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

  double _intervalMs(double elapsedMs, double startMs, double endMs) {
    if (elapsedMs <= startMs) return 0;
    if (elapsedMs >= endMs) return 1;
    return (elapsedMs - startMs) / (endMs - startMs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final elapsedMs = _controller.value * _totalDuration.inMilliseconds;

          final convergeT = Curves.easeOut
              .transform(_intervalMs(elapsedMs, 0, _convergeEndMs.toDouble()));
          final emberOpacity = 1 -
              Curves.easeIn.transform(
                  _intervalMs(elapsedMs, _convergeEndMs.toDouble(), _igniteEndMs.toDouble()));

          // Il lampo d'accensione: sale rapido e si dissolve.
          final ignitePhase = _intervalMs(
              elapsedMs, _convergeEndMs.toDouble(), (_convergeEndMs + 200).toDouble());
          final igniteFlash = ignitePhase > 0 && ignitePhase < 1
              ? sin(ignitePhase * pi) // sale e scende in una curva morbida
              : 0.0;

          // Il logo reale sfuma dentro subito dopo l'accensione...
          final logoFadeIn = Curves.easeOut.transform(
              _intervalMs(elapsedMs, _convergeEndMs.toDouble(), _igniteEndMs.toDouble()));
          // ...resta fermo, fisso, per tutta l'attesa...
          // ...poi sfuma verso il nero prima di passare alla home. Niente
          // bagliore pulsante: resta fermo e stabile, come richiesto.
          final logoFadeOut = 1 -
              Curves.easeIn.transform(_intervalMs(
                  elapsedMs, _holdEndMs.toDouble(), _totalDuration.inMilliseconds.toDouble()));
          final logoOpacity = logoFadeIn * logoFadeOut;

          return LayoutBuilder(
            builder: (context, constraints) {
              final center =
                  Offset(constraints.maxWidth / 2, constraints.maxHeight / 2 - 20);

              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  if (emberOpacity > 0)
                    CustomPaint(
                      painter: _EmberFormationPainter(
                        embers: _embers,
                        convergeT: convergeT,
                        opacity: emberOpacity,
                        center: center,
                        boxWidth: _vBoxWidth,
                        boxHeight: _vBoxHeight,
                        screenSize: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                  if (igniteFlash > 0)
                    Center(
                      child: Container(
                        width: 60 + igniteFlash * 500,
                        height: 60 + igniteFlash * 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(igniteFlash * 0.9),
                              VexonColors.brandRed.withOpacity(igniteFlash * 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (logoOpacity > 0)
                    Center(
                      child: Opacity(
                        opacity: logoOpacity,
                        child: Image.asset('assets/icons/logo_splash.png', width: 300),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Disegna le scintille mentre convergono dai bordi dello schermo verso il
/// contorno della V — stesso stile ember (alone rosso + nucleo ambra) già
/// usato in `particle_background.dart`, per coerenza visiva con il resto
/// dell'app.
class _EmberFormationPainter extends CustomPainter {
  final List<_Ember> embers;
  final double convergeT;
  final double opacity;
  final Offset center;
  final double boxWidth;
  final double boxHeight;
  final Size screenSize;

  static const _emberCore = Color(0xFFFFA552);

  _EmberFormationPainter({
    required this.embers,
    required this.convergeT,
    required this.opacity,
    required this.center,
    required this.boxWidth,
    required this.boxHeight,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    for (final ember in embers) {
      final localT =
          ((convergeT - ember.delay) / (1 - ember.delay)).clamp(0.0, 1.0);
      final eased = Curves.easeInOutCubic.transform(localT);

      final startPx = Offset(ember.start.dx * screenSize.width, ember.start.dy * screenSize.height);
      final targetPx = Offset(
        center.dx - boxWidth / 2 + ember.target.dx * boxWidth,
        center.dy - boxHeight / 2 + ember.target.dy * boxHeight,
      );

      final pos = Offset.lerp(startPx, targetPx, eased)!;
      final localOpacity = (0.4 + eased * 0.6) * opacity;

      final glowPaint = Paint()
        ..color = VexonColors.brandRed.withOpacity(localOpacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(pos, ember.size * 2.0, glowPaint);

      final corePaint = Paint()..color = _emberCore.withOpacity(localOpacity * 0.85);
      canvas.drawCircle(pos, ember.size * 0.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberFormationPainter oldDelegate) => true;
}
