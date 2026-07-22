import 'dart:io';
import 'package:path/path.dart' as p;
import '../../models/game.dart';

class SteamScanner {
  static const List<String> _commonSteamPaths = [
    r'C:\Program Files (x86)\Steam',
    r'C:\Program Files\Steam',
  ];

  Future<List<Game>> scan() async {
    final games = <Game>[];

    String? steamPath;
    for (final path in _commonSteamPaths) {
      if (await Directory(path).exists()) {
        steamPath = path;
        break;
      }
    }
    if (steamPath == null) return games;

    // Scansiona TUTTE le librerie Steam, non solo quella di default —
    // fondamentale se i giochi sono installati su un disco diverso da C:,
    // molto comune.
    final libraryPaths = await _findSteamLibraryPaths(steamPath);

    for (final libraryPath in libraryPaths) {
      final steamAppsDir = Directory(p.join(libraryPath, 'steamapps'));
      if (!await steamAppsDir.exists()) continue;

      final acfFiles = steamAppsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.acf'));

      for (final file in acfFiles) {
        final content = await file.readAsString();
        final appId = _extractAcfValue(content, 'appid');
        final name = _extractAcfValue(content, 'name');
        final installDir = _extractAcfValue(content, 'installdir');

        if (appId == null || name == null) continue;

        games.add(Game(
          id: 'steam_$appId',
          title: name,
          executablePath: installDir != null
              ? p.join(steamAppsDir.path, 'common', installDir)
              : '',
          source: GameSource.steam,
          // Cover "verticale" ufficiale (la stessa mostrata nella libreria
          // di Steam), servita dal CDN pubblico Steam — non richiede
          // autenticazione, solo l'appId.
          coverImagePath:
              'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/library_600x900.jpg',
          steamAppId: appId,
        ));
      }
    }

    return games;
  }

  /// Trova tutte le cartelle libreria Steam, inclusa quella di default e
  /// quelle aggiuntive su altri dischi, leggendo
  /// steamapps/libraryfolders.vdf. Il parsing è volutamente semplice (una
  /// regex sui campi "path", non un vero parser VDF) — sufficiente per
  /// questo scopo ed è lo stesso approccio usato da molti tool community.
  Future<List<String>> _findSteamLibraryPaths(String steamPath) async {
    final paths = <String>{steamPath}; // la libreria di default c'è sempre

    final vdfFile = File(p.join(steamPath, 'steamapps', 'libraryfolders.vdf'));
    if (await vdfFile.exists()) {
      try {
        final content = await vdfFile.readAsString();
        final matches = RegExp(r'"path"\s*"([^"]+)"').allMatches(content);
        for (final match in matches) {
          final rawPath = match.group(1);
          if (rawPath == null) continue;
          // Nel file i backslash sono doppi (escape VDF): "D:\\Giochi"
          paths.add(rawPath.replaceAll(r'\\', r'\'));
        }
      } catch (_) {
        // Se il file esiste ma è malformato, ripieghiamo comunque sulla
        // sola libreria di default invece di far fallire tutto.
      }
    }

    return paths.toList();
  }

  /// Estrae un valore semplice da un file .acf (formato VDF di Valve),
  /// es: "name"		"Half-Life 2"
  String? _extractAcfValue(String content, String key) {
    final pattern = RegExp('"$key"\\s+"([^"]+)"', caseSensitive: false);
    final match = pattern.firstMatch(content);
    return match?.group(1);
  }
}
