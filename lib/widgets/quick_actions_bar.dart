import 'package:flutter/material.dart';
import '../services/system_actions_service.dart';
import '../theme/vexon_colors.dart';

/// Azioni rapide in stile "sostituto del desktop": scorciatoie per Esplora
/// file/Impostazioni/Task Manager, e spegni/riavvia/sospendi. Le azioni
/// distruttive (spegni/riavvia/sospendi) chiedono sempre conferma —
/// chiudono ogni programma aperto, giochi inclusi.
///
/// Nessuna cornice propria: è pensato per vivere dentro la barra di
/// sistema unificata ([BottomTaskbar]), che fornisce lo sfondo condiviso.
class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.folder_open,
          tooltip: 'Esplora file',
          onTap: SystemActionsService.openFileExplorer,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          icon: Icons.settings,
          tooltip: 'Impostazioni Windows',
          onTap: SystemActionsService.openSettings,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          icon: Icons.speed,
          tooltip: 'Task Manager',
          onTap: SystemActionsService.openTaskManager,
        ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(height: 20, child: VerticalDivider(color: Colors.white12, width: 1)),
          ),
          _ActionButton(
            icon: Icons.bedtime,
            tooltip: 'Sospendi',
            onTap: () => _confirmAndRun(
              context,
              title: 'Sospendere il PC?',
              action: SystemActionsService.sleep,
            ),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            icon: Icons.restart_alt,
            tooltip: 'Riavvia',
            onTap: () => _confirmAndRun(
              context,
              title: 'Riavviare il PC?',
              action: SystemActionsService.restart,
            ),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            icon: Icons.power_settings_new,
            tooltip: 'Spegni',
            color: VexonColors.critical,
            onTap: () => _confirmAndRun(
              context,
              title: 'Spegnere il PC?',
              action: SystemActionsService.shutdown,
            ),
          ),
      ],
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VexonColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(color: VexonColors.textPrimary)),
        content: const Text(
          'Tutti i programmi aperti (giochi inclusi) verranno chiusi, con eventuale perdita di progressi non salvati.',
          style: TextStyle(color: VexonColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: VexonColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VexonColors.critical,
              foregroundColor: Colors.white,
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed == true) await action();
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? VexonColors.textSecondary;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovering ? color.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
