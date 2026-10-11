import 'dart:async';
import 'package:flutter/material.dart';
import '../services/system_tray_service.dart';
import '../theme/vexon_colors.dart';
import '../theme/vexon_typography.dart';
import 'disk_space_bar.dart';
import 'quick_actions_bar.dart';
import 'scan_divider.dart';
import 'system_tray_bar.dart';

/// Barra di sistema unificata, ancorata in basso su tutta la larghezza —
/// come la taskbar di Windows. Riunisce in un'unica cornice le sezioni che
/// prima erano "pillole" separate: azioni rapide, spazio disco, stato
/// WiFi/volume/batteria/rete, e data/ora completa a destra (stesso posto
/// dell'orologio di sistema di Windows).
///
/// Ha una linea accesa animata sul bordo SUPERIORE — la stessa
/// [ScanDivider] usata sotto la barra in alto — così lo schermo resta
/// "incorniciato" simmetricamente sopra e sotto.
class BottomTaskbar extends StatefulWidget implements PreferredSizeWidget {
  final SystemTrayStats? stats;
  final VoidCallback onToggleMute;

  const BottomTaskbar({super.key, this.stats, required this.onToggleMute});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  State<BottomTaskbar> createState() => _BottomTaskbarState();
}

class _BottomTaskbarState extends State<BottomTaskbar> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // L'orologio deve aggiornarsi ogni secondo anche se nient'altro nella
    // barra cambia (es. nessun dato di sistema disponibile) — un timer
    // dedicato invece di dipendere dagli aggiornamenti di [stats].
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  static const _weekdays = [
    'LUNEDÌ', 'MARTEDÌ', 'MERCOLEDÌ', 'GIOVEDÌ', 'VENERDÌ', 'SABATO', 'DOMENICA'
  ];
  static const _months = [
    'GENNAIO', 'FEBBRAIO', 'MARZO', 'APRILE', 'MAGGIO', 'GIUGNO',
    'LUGLIO', 'AGOSTO', 'SETTEMBRE', 'OTTOBRE', 'NOVEMBRE', 'DICEMBRE',
  ];

  String _clockLabel(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String _dateLabel(DateTime now) {
    return '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(height: 26, child: VerticalDivider(color: Colors.white12, width: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final disks = widget.stats?.disks ?? const [];
    final hasTraySection = widget.stats?.wifi != null ||
        widget.stats?.volume != null ||
        widget.stats?.battery != null ||
        widget.stats?.network != null;

    return Container(
      height: widget.preferredSize.height,
      color: VexonColors.surface,
      child: Column(
        children: [
          const ScanDivider(reverse: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const QuickActionsBar(),
                  if (disks.isNotEmpty) ...[
                    _sectionDivider(),
                    DiskSpaceBar(disks: disks),
                  ],
                  const Spacer(),
                  if (hasTraySection) ...[
                    SystemTrayBar(stats: widget.stats, onToggleMute: widget.onToggleMute),
                    _sectionDivider(),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _clockLabel(now),
                        style: VexonTypography.digital(fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateLabel(now),
                        style: VexonTypography.caption(
                          color: VexonColors.textDisabled,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
