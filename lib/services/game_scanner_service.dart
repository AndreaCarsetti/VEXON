import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/game.dart';

/// Scansiona le librerie di gioco installate sul PC.
///
/// Supporta Steam (file .acf) ed Epic Games (file .item, formato JSON).
/// GOG può essere aggiunto come implementazione parallela con la stessa
/// interfaccia — vedi TODO in fondo al file.
class GameScannerService {
  /// Percorsi comuni dove Steam viene installato su Windows.
  static const List<String> _commonSteamPaths = [
    r'C:\Program Files (x86)\Steam',
    r'C:\Program Files\Steam',
  ];

  /// Percorso fisso dei manifest di Epic Games — a differenza di Steam,
  /// Epic non lo rende configurabile, è sempre qui.
  static const String _epicManifestsPath =
      r'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests';

  Future<List<Game>> scanAll() async {
    final games = <Game>[];
    games.addAll(await _scanSteam());
    games.addAll(await _scanEpic());
    // TODO: games.addAll(await _scanGog());
    return games;
  }

  Future<List<Game>> _scanSteam() async {
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
    // molto comune. Prima veniva scansionata solo la cartella
    // steamapps dentro l'installazione principale di Steam.
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
          // di Steam) servita dal CDN pubblico Steam — non richiede alcuna
          // autenticazione, solo l'appId. Se un gioco non ha questa
          // immagine (rara per titoli molto vecchi/minori), Steam CDN
          // risponde 404 e la GameCard mostra comunque il placeholder.
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

  Future<List<Game>> _scanEpic() async {
    final games = <Game>[];

    final manifestsDir = Directory(_epicManifestsPath);
    if (!await manifestsDir.exists()) return games;

    final itemFiles = manifestsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.item'));

    for (final file in itemFiles) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        // Gli strumenti di sviluppo Unreal Engine hanno bIsApplication a
        // false — non sono giochi, li saltiamo.
        if (json['bIsApplication'] == false) continue;

        final displayName = json['DisplayName'] as String?;
        final installLocation = json['InstallLocation'] as String?;
        final launchExecutable = json['LaunchExecutable'] as String?;
        final appName = json['AppName'] as String?; // ID interno Epic

        if (displayName == null || installLocation == null) continue;

        games.add(Game(
          id: 'epic_${appName ?? displayName}',
          title: displayName,
          executablePath: launchExecutable != null
              ? p.join(installLocation, launchExecutable)
              : installLocation,
          source: GameSource.epic,
          // Le cover di Epic richiedono di interrogare il loro catalogo
          // (CatalogNamespace + CatalogItemId presenti nel manifest) —
          // non c'è un CDN diretto come per Steam, da implementare a parte.
          coverImagePath: null,
        ));
      } catch (_) {
        // Un singolo manifest corrotto/malformato non deve bloccare la
        // scansione degli altri — lo saltiamo e proseguiamo.
        continue;
      }
    }

    return games;
  }
}
