import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:win32/win32.dart';
import '../../models/game.dart';
import 'win32_registry_utils.dart';

class GogScanner {
  /// GOG Galaxy scrive qui una sottochiave per ogni gioco installato, con
  /// il proprio gameID (numerico) come nome della sottochiave.
  static const _gogGamesKeyPath = r'SOFTWARE\WOW6432Node\GOG.com\Games';

  Future<List<Game>> scan() async {
    if (!Platform.isWindows) return [];

    final games = <Game>[];

    final hKey = Win32RegistryUtils.openKey(HKEY_LOCAL_MACHINE, _gogGamesKeyPath);
    if (hKey == null) return games; // GOG Galaxy non installato o nessun gioco: normale

    try {
      for (final subkeyName in Win32RegistryUtils.enumSubkeyNames(hKey)) {
        final subkeyPath = '$_gogGamesKeyPath\\$subkeyName';
        final hSubkey = Win32RegistryUtils.openKey(HKEY_LOCAL_MACHINE, subkeyPath);
        if (hSubkey == null) continue;

        try {
          final gameId = Win32RegistryUtils.getStringValue(hSubkey, 'gameID') ?? subkeyName;
          final exeName = Win32RegistryUtils.getStringValue(hSubkey, 'exe');
          final path = Win32RegistryUtils.getStringValue(hSubkey, 'path');
          final title = Win32RegistryUtils.getStringValue(hSubkey, 'gameName') ??
              Win32RegistryUtils.getStringValue(hSubkey, 'startMenuLink');

          if (path == null || title == null) continue;

          final executablePath = exeName != null ? '$path\\$exeName' : path;

          games.add(Game(
            id: 'gog_$gameId',
            title: title,
            executablePath: executablePath,
            source: GameSource.gog,
            coverImagePath: await _fetchCoverUrl(gameId),
          ));
        } finally {
          Win32RegistryUtils.closeKey(hSubkey);
        }
      }
    } finally {
      Win32RegistryUtils.closeKey(hKey);
    }

    return games;
  }

  /// L'API pubblica di GOG (nessuna chiave richiesta) non offre una vera
  /// cover "verticale" come Steam, ma espone alcune immagini promozionali
  /// del prodotto — si prova la più adatta come sostituto, in ordine di
  /// preferenza.
  Future<String?> _fetchCoverUrl(String gameId) async {
    try {
      final uri = Uri.parse('https://api.gog.com/products/$gameId?expand=images');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final images = json['images'] as Map<String, dynamic>?;
      if (images == null) return null;

      for (final field in ['logo2x', 'background', 'icon']) {
        final value = images[field] as String?;
        if (value == null || value.isEmpty) continue;
        // I campi immagine GOG sono protocol-relative ("//images...").
        return value.startsWith('//') ? 'https:$value' : value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
