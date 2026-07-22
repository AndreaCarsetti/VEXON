import 'package:flutter/material.dart';

/// Rappresenta un gioco rilevato in una delle librerie supportate
/// (Steam, Epic, GOG, Battle.net, EA, Ubisoft Connect, ...) oppure aggiunto
/// a mano dall'utente.
class Game {
  final String id;
  final String title;
  final String executablePath;
  final String? coverImagePath;
  final GameSource source;
  final DateTime? lastPlayed;

  /// AppID Steam (solo per giochi source == steam) — serve per costruire
  /// l'URL della cover sul CDN e per lanciare il gioco tramite protocollo
  /// steam://rungameid/<appid> invece di eseguire direttamente il binario
  /// nella cartella d'installazione (che spesso non funziona con giochi
  /// che usano DRM o anticheat legati al client Steam).
  final String? steamAppId;

  const Game({
    required this.id,
    required this.title,
    required this.executablePath,
    required this.source,
    this.coverImagePath,
    this.lastPlayed,
    this.steamAppId,
  });
}

enum GameSource {
  steam,
  epic,
  gog,
  battlenet,
  ea,
  ubisoft,
  manual,
}

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
      case GameSource.ea:
        return 'EA App';
      case GameSource.ubisoft:
        return 'Ubisoft Connect';
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
      case GameSource.ea:
        return Icons.sports_esports;
      case GameSource.ubisoft:
        return Icons.flag;
      case GameSource.manual:
        return Icons.folder;
    }
  }
}
