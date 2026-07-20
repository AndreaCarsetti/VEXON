import 'package:flutter/material.dart';
import '../models/game.dart';
import '../theme/vexon_colors.dart';

class GameCard extends StatefulWidget {
  final Game game;
  final VoidCallback onLaunch;
  final VoidCallback? onLongPress;

  const GameCard({super.key, required this.game, required this.onLaunch, this.onLongPress});

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _hovering = false;
  bool _pressing = false;

  double get _scale {
    if (_pressing) return 0.96;
    if (_hovering) return 1.035;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressing = false;
      }),
      child: GestureDetector(
        onTap: widget.onLaunch,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: VexonColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering ? VexonColors.brandRed : Colors.transparent,
                width: 2,
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: VexonColors.brandRed.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: widget.game.coverImagePath != null
                            ? Image.network(
                                widget.game.coverImagePath!,
                                fit: BoxFit.cover,
                                // Copertina non ancora scaricata: placeholder
                                // silenzioso invece di uno spinner — con
                                // decine di card assieme uno spinner per
                                // ognuna è più fastidioso che utile.
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(color: VexonColors.surfaceElevated);
                                },
                                // Copertina assente sul CDN (404) o nessuna
                                // connessione: stesso placeholder usato per
                                // i giochi senza coverImagePath.
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: VexonColors.surfaceElevated,
                                  child: const Icon(Icons.videogame_asset,
                                      color: VexonColors.textSecondary, size: 40),
                                ),
                              )
                            : Container(
                                color: VexonColors.surfaceElevated,
                                child: const Icon(Icons.videogame_asset,
                                    color: VexonColors.textSecondary, size: 40),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          widget.game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VexonColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Badge piattaforma — piccolo indicatore in alto a
                  // sinistra per distinguere a colpo d'occhio Steam/Epic/GOG
                  // ora che la libreria aggrega più fonti.
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        widget.game.source.icon,
                        size: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
