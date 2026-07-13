import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/kiosk_service.dart';
import '../services/window_state.dart';
import '../theme/vexon_colors.dart';

/// Barra sottile (32px) in alto, visibile SOLO quando l'app non è in
/// modalità kiosk (cioè dopo che l'utente è uscito tenendo premuto ESC).
///
/// A differenza di un overlay "galleggiante", questo widget fa parte del
/// normale flusso di layout (va messo sopra il resto del contenuto in una
/// Column, non in uno Stack/Positioned) — così quando compare spinge giù
/// il contenuto dell'app invece di sovrapporsi e coprirlo.
///
/// Contiene:
/// - un'area trascinabile trasparente per spostare la finestra (il
///   titleBarStyle è `hidden`, quindi Windows non offre più questo
///   comportamento di serie) — niente logo/testo qui per non duplicare
///   quello già presente nella TopBar dell'app sotto
/// - tre pulsanti in alto a destra: riduci a icona, schermo intero, chiudi
class WindowedTitleBar extends StatelessWidget {
  const WindowedTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WindowState.isKiosk,
      builder: (context, isKiosk, _) {
        if (isKiosk) return const SizedBox.shrink();

        return DragToMoveArea(
          child: Container(
            height: 32,
            color: VexonColors.background,
            child: Row(
              children: [
                const Expanded(child: SizedBox()), // area trascinabile
                _WindowButton(
                  icon: Icons.remove,
                  tooltip: 'Riduci a icona',
                  onPressed: () => windowManager.minimize(),
                ),
                _WindowButton(
                  icon: Icons.crop_square,
                  tooltip: 'Schermo intero',
                  onPressed: () => KioskService.enterKiosk(),
                ),
                _WindowButton(
                  icon: Icons.close,
                  tooltip: 'Chiudi',
                  hoverColor: VexonColors.critical,
                  onPressed: () => windowManager.close(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.hoverColor ?? Colors.white12;
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: 32,
            color: _hovering ? hoverColor : Colors.transparent,
            child: Icon(widget.icon, size: 14, color: VexonColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
