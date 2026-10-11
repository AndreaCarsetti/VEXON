import 'package:flutter/material.dart';
import '../services/system_tray_service.dart';
import '../theme/vexon_colors.dart';

/// WiFi, volume, batteria, rete — per la visione di VEXON come sostituto
/// del desktop, non solo un launcher di giochi. Ogni icona è opzionale: se
/// un dato non è disponibile (niente WiFi, PC desktop senza batteria...)
/// la sua icona semplicemente non compare, invece di mostrare un
/// placeholder rotto.
///
/// Nessuna cornice propria: vive dentro la barra di sistema unificata
/// ([BottomTaskbar]).
class SystemTrayBar extends StatelessWidget {
  final SystemTrayStats? stats;
  final VoidCallback onToggleMute;

  const SystemTrayBar({super.key, this.stats, required this.onToggleMute});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final items = <Widget>[];

    if (s?.wifi != null) {
      items.add(_TrayItem(
        icon: _wifiIcon(s!.wifi!.signalPercent),
        label: '${s.wifi!.signalPercent}%',
        tooltip: s.wifi!.ssid,
      ));
    }

    if (s?.volume != null) {
      items.add(_TrayItem(
        icon: s!.volume!.muted ? Icons.volume_off : _volumeIcon(s.volume!.percent),
        label: s.volume!.muted ? 'MUTO' : '${s.volume!.percent}%',
        tooltip: s.volume!.muted ? 'Audio disattivato — clicca per riattivare' : 'Clicca per silenziare',
        onTap: onToggleMute,
        highlighted: s.volume!.muted,
      ));
    }

    if (s?.battery != null) {
      items.add(_TrayItem(
        icon: s!.battery!.charging ? Icons.battery_charging_full : _batteryIcon(s.battery!.percent),
        label: '${s.battery!.percent}%',
        tooltip: s.battery!.charging ? 'In carica' : 'Batteria',
        highlighted: s.battery!.percent < 20 && !s.battery!.charging,
      ));
    }

    if (s?.network != null) {
      items.add(_NetworkItem(network: s!.network!));
    }

    if (s?.security != null) {
      items.add(_SecurityItem(security: s!.security!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          items[i],
        ],
      ],
    );
  }

  // Icone Material "classiche" scelte apposta — la famiglia estesa con
  // varianti per numero di tacche (wifi_2_bar, battery_5_bar...) esiste in
  // alcune versioni del set icone ma non sono sicuro sia disponibile in
  // ogni versione del pacchetto Flutter: meglio restare su nomi
  // indiscutibilmente presenti da sempre, e lasciare che sia la
  // percentuale in testo a comunicare l'intensità.
  IconData _wifiIcon(int percent) => percent > 0 ? Icons.wifi : Icons.wifi_off;

  IconData _volumeIcon(int percent) {
    if (percent <= 0) return Icons.volume_mute;
    if (percent < 50) return Icons.volume_down;
    return Icons.volume_up;
  }

  IconData _batteryIcon(int percent) {
    if (percent <= 15) return Icons.battery_alert;
    return Icons.battery_std;
  }
}

class _NetworkItem extends StatelessWidget {
  final NetworkStatus network;
  const _NetworkItem({required this.network});

  String _formatSpeed(double kbps) {
    if (kbps >= 1024) return '${(kbps / 1024).toStringAsFixed(1)}MB/s';
    return '${kbps.toStringAsFixed(0)}KB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Rete',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_downward, size: 12, color: VexonColors.textSecondary),
          const SizedBox(width: 2),
          Text(_formatSpeed(network.downKBps),
              style: const TextStyle(color: VexonColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_upward, size: 12, color: VexonColors.textSecondary),
          const SizedBox(width: 2),
          Text(_formatSpeed(network.upKBps),
              style: const TextStyle(color: VexonColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SecurityItem extends StatelessWidget {
  final SecurityStatus security;
  const _SecurityItem({required this.security});

  @override
  Widget build(BuildContext context) {
    final protected = security.realTimeProtection;
    final color = protected ? VexonColors.success : VexonColors.critical;
    final ageNote =
        security.signatureAgeDays != null ? ' · definizioni di ${security.signatureAgeDays} giorni fa' : '';
    final tooltip = protected
        ? 'Protezione Windows Defender attiva$ageNote'
        : 'Protezione Windows Defender disattivata — normale se usi un altro antivirus';

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(protected ? Icons.shield : Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            protected ? 'PROTETTO' : 'A RISCHIO',
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlighted;

  const _TrayItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? VexonColors.warning : VexonColors.textSecondary;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );

    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? content
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: onTap, child: content),
            ),
    );
  }
}
