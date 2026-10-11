import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/hardware_monitor_service.dart';
import '../theme/vexon_colors.dart';
import '../theme/vexon_typography.dart';
import 'scan_divider.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool gameModeActive;
  final ValueChanged<bool> onGameModeToggle;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddGame;
  final VoidCallback onCleanRam;
  final HardwareStats? stats;

  const TopBar({
    super.key,
    required this.gameModeActive,
    required this.onGameModeToggle,
    required this.onSearchChanged,
    required this.onAddGame,
    required this.onCleanRam,
    this.stats,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: VexonColors.surface,
      // Column invece di Stack: il contenuto va nella riga "Expanded" (che
      // lo centra verticalmente come una Row normale farebbe), la linea
      // animata è una striscia a parte sotto — niente overlay manuale con
      // Positioned che rischia di disallineare tutto il resto.
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _BrandSymbol(stats: stats),
                  const SizedBox(width: 28),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onChanged: onSearchChanged,
                        style: VexonTypography.body(),
                        decoration: InputDecoration(
                          hintText: 'Cerca un gioco…',
                          hintStyle: VexonTypography.body(color: VexonColors.textSecondary),
                          filled: true,
                          fillColor: VexonColors.surfaceElevated,
                          prefixIcon:
                              const Icon(Icons.search, color: VexonColors.textSecondary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _CleanRamButton(onPressed: onCleanRam),
                  const SizedBox(width: 12),
                  _AddGameButton(onPressed: onAddGame),
                  const SizedBox(width: 12),
                  _GameModeToggle(active: gameModeActive, onToggle: onGameModeToggle),
                ],
              ),
            ),
          ),
          const ScanDivider(),
        ],
      ),
    );
  }
}

/// Il simbolo V in top bar, con un alone rosso che riflette il carico
/// hardware reale e reagisce all'hover.
///
/// L'intensità di base (colore, sfocatura, opacità) è calcolata dal carico
/// CPU/GPU corrente invece che animata con un timer: sale e scende insieme
/// ai dati veri che arrivano da [HardwareStats], quindi "respira" in modo
/// organico senza bisogno di un AnimationController dedicato — e resta
/// coerente con la scelta, già fatta nel boot sequence, di non far
/// lampeggiare il logo con un pulsare finto e continuo.
///
/// Sull'hover si aggiunge un secondo livello, quello sì puramente
/// decorativo: leggero scale-up e un anello che ruota lentamente attorno
/// al simbolo ([_OrbitRingPainter]), per dare un feedback immediato che il
/// simbolo è un elemento vivo dell'interfaccia — senza il tono "mirino da
/// FPS" che davano i corner brackets usati altrove (es. sulle card dei
/// giochi), fuori posto per un semplice elemento di brand.
class _BrandSymbol extends StatefulWidget {
  final HardwareStats? stats;
  const _BrandSymbol({this.stats});

  @override
  State<_BrandSymbol> createState() => _BrandSymbolState();
}

class _BrandSymbolState extends State<_BrandSymbol> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  void _setHovering(bool value) {
    setState(() => _hovering = value);
    if (value) {
      _ringController.repeat();
    } else {
      _ringController.stop();
    }
  }

  /// 0.0 (sistema a riposo) — 1.0 (CPU o GPU quasi al massimo).
  double get _loadFraction {
    final stats = widget.stats;
    if (stats == null) return 0.0;
    final cpu = stats.cpuUsagePercent;
    final gpu = stats.gpuUsagePercent ?? 0;
    return (cpu > gpu ? cpu : gpu).clamp(0, 100) / 100;
  }

  @override
  Widget build(BuildContext context) {
    final load = _loadFraction;
    // Sotto carico il bagliore non solo cresce, si scalda: dal rosso brand
    // verso un rosso-arancio più "caldo", come una lama che si surriscalda.
    final glowColor = Color.lerp(VexonColors.brandRed, VexonColors.warning, load * 0.55)!;
    final baseOpacity = 0.32 + load * 0.28;
    final baseBlur = 18.0 + load * 14.0;
    final baseSpread = 1.0 + load * 3.0;

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: AnimatedScale(
        scale: _hovering ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          // Un po' più grande del cerchio del glow, per lasciare respiro
          // all'anello che gli ruota attorno senza tagliarlo ai bordi.
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedOpacity(
                opacity: _hovering ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: AnimatedBuilder(
                  animation: _ringController,
                  builder: (context, child) => Transform.rotate(
                    angle: _ringController.value * 2 * math.pi,
                    child: child,
                  ),
                  child: CustomPaint(
                    size: const Size(58, 58),
                    painter: _OrbitRingPainter(color: glowColor),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(_hovering ? baseOpacity + 0.15 : baseOpacity),
                      blurRadius: _hovering ? baseBlur + 6 : baseBlur,
                      spreadRadius: _hovering ? baseSpread + 1 : baseSpread,
                    ),
                  ],
                ),
                child: Image.asset('assets/icons/symbol.png', height: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anello sottile e discontinuo (due archi contrapposti, non un cerchio
/// pieno) che ruota lentamente attorno al simbolo sull'hover — un effetto
/// più "elegante/da scanner" rispetto a un mirino, che dava un'idea troppo
/// aggressiva da FPS per un semplice elemento di brand.
class _OrbitRingPainter extends CustomPainter {
  final Color color;
  _OrbitRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withOpacity(0), color, color.withOpacity(0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    // Due archi da ~70° l'uno opposto all'altro, invece di un cerchio
    // continuo: legge meglio come "elemento che ruota" piuttosto che come
    // un semplice bordo statico animato.
    const sweep = 1.25; // ~70° in radianti
    canvas.drawArc(rect, 0, sweep, false, paint);
    canvas.drawArc(rect, math.pi, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) => oldDelegate.color != color;
}

/// Pulsante per la pulizia RAM — sgonfia il working set dei processi in
/// esecuzione (vedi [RamCleanerService]). Stesso stile neutro
/// dell'_AddGameButton: anche questo è un'azione secondaria rispetto al
/// Game Mode.
class _CleanRamButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CleanRamButton({required this.onPressed});

  @override
  State<_CleanRamButton> createState() => _CleanRamButtonState();
}

class _CleanRamButtonState extends State<_CleanRamButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering
                ? Color.alphaBlend(Colors.white.withOpacity(0.06), VexonColors.surfaceElevated)
                : VexonColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cleaning_services, size: 16, color: VexonColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Pulisci RAM',
                style: TextStyle(
                  color: VexonColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsante per aggiungere un gioco manualmente, sempre visibile. Grigio
/// neutro di proposito — deve restare in secondo piano rispetto al pulsante
/// Game Mode, che è quello che vogliamo risalti visivamente.
class _AddGameButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AddGameButton({required this.onPressed});

  @override
  State<_AddGameButton> createState() => _AddGameButtonState();
}

class _AddGameButtonState extends State<_AddGameButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering
                ? Color.alphaBlend(Colors.white.withOpacity(0.06), VexonColors.surfaceElevated)
                : VexonColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: VexonColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Aggiungi gioco',
                style: TextStyle(
                  color: VexonColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameModeToggle extends StatefulWidget {
  final bool active;
  final ValueChanged<bool> onToggle;

  const _GameModeToggle({required this.active, required this.onToggle});

  @override
  State<_GameModeToggle> createState() => _GameModeToggleState();
}

class _GameModeToggleState extends State<_GameModeToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.active) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _GameModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.active) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onToggle(!widget.active),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          // Il bagliore "respira" tra 0.5 e 0.85 di opacità mentre attivo —
          // dà la sensazione che il Boost sia davvero "vivo", non solo un
          // interruttore acceso in modo statico.
          final glowOpacity = widget.active
              ? 0.5 + Curves.easeInOut.transform(_pulseController.value) * 0.35
              : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.active ? VexonColors.brandRed : VexonColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: VexonColors.brandRed.withOpacity(glowOpacity),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt,
                    size: 16,
                    color: widget.active ? Colors.white : VexonColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  widget.active ? 'GAME MODE ON' : 'GAME MODE',
                  style: TextStyle(
                    color: widget.active ? Colors.white : VexonColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
