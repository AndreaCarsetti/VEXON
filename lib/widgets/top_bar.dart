import 'package:flutter/material.dart';
import '../theme/vexon_colors.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool gameModeActive;
  final ValueChanged<bool> onGameModeToggle;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddGame;

  const TopBar({
    super.key,
    required this.gameModeActive,
    required this.onGameModeToggle,
    required this.onSearchChanged,
    required this.onAddGame,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: VexonColors.surface,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Image.asset('assets/icons/symbol.png', height: 36),
          const SizedBox(width: 12),
          const Text(
            'VEXON',
            style: TextStyle(
              color: VexonColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: onSearchChanged,
                style: const TextStyle(color: VexonColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cerca un gioco…',
                  hintStyle: const TextStyle(color: VexonColors.textSecondary),
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
          _AddGameButton(onPressed: onAddGame),
          const SizedBox(width: 12),
          _GameModeToggle(active: gameModeActive, onToggle: onGameModeToggle),
        ],
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
