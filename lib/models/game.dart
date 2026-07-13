import 'package:flutter/material.dart';

/// Rappresenta un gioco rilevato in una delle librerie supportate
/// (Steam, Epic, GOG, ...).
class Game {
  final String id;
  final String title;
  final String executablePath;
  final String? coverImagePath;
  final GameSource source;
  final DateTime? lastPlayed;

  const Game({
    required this.id,
    required this.title,
    required this.executablePath,
    required this.source,
    this.coverImagePath,
    this.lastPlayed,
  });
}

enum GameSource { steam, epic, gog, battlenet, manual }

extension GameSourceLabel on GameSource {
  String get label {
    switch (this) {
      case GameSource.steam:
        return 'Steam';
      case GameSource.epic:
        return 'Epic Games';
      case GameSource.gog:
        return 'GOG';
      case GameSource.battlenet:
        return 'Battle.net';
      case GameSource.manual:
        return 'Aggiunto manualmente';
    }
  }

  /// Icona compatta usata nel badge piattaforma sulla card del gioco.
  IconData get icon {
    switch (this) {
      case GameSource.steam:
        return Icons.window; // placeholder neutro: Flutter non ha un'icona Steam nativa
      case GameSource.epic:
        return Icons.gamepad;
      case GameSource.gog:
        return Icons.storefront;
      case GameSource.battlenet:
        return Icons.bolt;
      case GameSource.manual:
        return Icons.folder;
    }
  }
}
