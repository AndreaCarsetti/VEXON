import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../models/game.dart';

class EpicScanner {
  /// Percorso fisso dei manifest di Epic Games — a differenza di Steam,
  /// Epic non lo rende configurabile, è sempre qui.
  static const String _epicManifestsPath =
      r'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests';

  Future<List<Game>> scan() async {
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
        final catalogNamespace = json['CatalogNamespace'] as String?;
        final catalogItemId = json['CatalogItemId'] as String?;

        if (displayName == null || installLocation == null) continue;

        String? coverImagePath;
        if (catalogNamespace != null && catalogItemId != null) {
          coverImagePath = await _fetchCoverUrl(catalogNamespace, catalogItemId);
        }

        games.add(Game(
          id: 'epic_${appName ?? displayName}',
          title: displayName,
          executablePath: launchExecutable != null
              ? p.join(installLocation, launchExecutable)
              : installLocation,
          source: GameSource.epic,
          coverImagePath: coverImagePath,
        ));
      } catch (_) {
        // Un singolo manifest corrotto/malformato non deve bloccare la
        // scansione degli altri — lo saltiamo e proseguiamo.
        continue;
      }
    }

    return games;
  }

  /// Interroga il catalogo pubblico Epic (nessuna autenticazione richiesta,
  /// è lo stesso endpoint usato dal client stesso e da tool community come
  /// Legendary/Heroic) per ottenere l'immagine "verticale" del gioco.
  ///
  /// Il catalogo espone diverse varianti di immagine per lo stesso gioco
  /// (`keyImages`, ognuna con un `type` diverso); si prova una lista di tipi
  /// in ordine di preferenza, dalla verticale/porträt alla più generica, e
  /// si usa la prima disponibile.
  Future<String?> _fetchCoverUrl(String namespace, String catalogItemId) async {
    try {
      final uri = Uri.parse(
        'https://catalog-public-service-prod06.ol.epicgames.com/catalog/api/'
        'shared/namespace/$namespace/bulk/items'
        '?id=$catalogItemId&includeDLCDetails=false&includeMainGameDetails=false'
        '&country=US&locale=en',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final item = json[catalogItemId] as Map<String, dynamic>?;
      final keyImages = item?['keyImages'] as List<dynamic>?;
      if (keyImages == null) return null;

      const preferredTypes = [
        'DieselStoreFrontTall',
        'OfferImageTall',
        'Thumbnail',
        'DieselStoreFrontWide',
        'OfferImageWide',
      ];

      for (final type in preferredTypes) {
        for (final image in keyImages) {
          final map = image as Map<String, dynamic>;
          if (map['type'] == type && map['url'] is String) {
            return map['url'] as String;
          }
        }
      }
      return null;
    } catch (_) {
      // Nessuna connessione, timeout, o risposta inattesa: niente cover,
      // la GameCard userà il placeholder — non è un errore bloccante.
      return null;
    }
  }
}
