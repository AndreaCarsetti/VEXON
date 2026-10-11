import 'package:flutter/material.dart';
import '../services/system_tray_service.dart';
import '../theme/vexon_colors.dart';

/// Riga compatta con lo spazio usato/totale di ogni unità fissa rilevata.
/// Se non ci sono dischi (lettura fallita o nessuna unità fissa trovata),
/// non occupa spazio invece di mostrare un pannello vuoto.
///
/// Nessuna cornice propria: vive dentro la barra di sistema unificata
/// ([BottomTaskbar]).
class DiskSpaceBar extends StatelessWidget {
  final List<DiskInfo> disks;

  const DiskSpaceBar({super.key, required this.disks});

  @override
  Widget build(BuildContext context) {
    if (disks.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < disks.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          _DiskItem(disk: disks[i]),
        ],
      ],
    );
  }
}

class _DiskItem extends StatelessWidget {
  final DiskInfo disk;
  const _DiskItem({required this.disk});

  @override
  Widget build(BuildContext context) {
    final usedFraction = disk.totalGb > 0 ? (disk.usedGb / disk.totalGb).clamp(0.0, 1.0) : 0.0;
    final color = usedFraction > 0.9
        ? VexonColors.critical
        : usedFraction > 0.75
            ? VexonColors.warning
            : VexonColors.textSecondary;

    return Tooltip(
      message: '${disk.freeGb.toStringAsFixed(1)} GB liberi su ${disk.totalGb.toStringAsFixed(0)} GB',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storage, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                '${disk.drive} ${disk.usedGb.toStringAsFixed(0)}/${disk.totalGb.toStringAsFixed(0)}GB',
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              width: 62,
              height: 3,
              child: LinearProgressIndicator(
                value: usedFraction,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
