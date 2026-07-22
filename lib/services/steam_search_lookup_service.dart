import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'game_lookup_service.dart';

/// Riconosce i giochi cercandoli sullo store di Steam invece che su IGDB.
/// Vantaggio: `store.steampowered.com/api/storesearch` è pubblico, nessuna
/// registrazione o chiave richiesta — funziona da subito. Limite: conosce
/// solo giochi effettivamente presenti su Steam, quindi per titoli
/// esclusivi Epic/GOG/Battle.net il match può mancare più spesso che con
/// IGDB. Buona opzione di partenza "a costo zero"; chi vuole una copertura
/// più ampia può passare a IGDB dalle impostazioni.
///
/// Restituendo l'appid del risultato, la cover è la stessa identica usata
/// per i giochi rilevati direttamente da Steam (stesso CDN, stessa
/// risoluzione), quindi qualitativamente non c'è differenza quando il
/// gioco viene trovato.
class SteamSearchLookupService implements GameLookupService {
  Map<String, dynamic>? _diskCache;

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'steam_search_cache_v2.json'));
  }

  Future<Map<String, dynamic>> _loadDiskCache() async {
    if (_diskCache != null) return _diskCache!;
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        _diskCache = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {
      // cache assente o corrotta: si riparte da vuota
    }
    return _diskCache ??= {};
  }

  Future<void> _saveDiskCache() async {
    if (_diskCache == null) return;
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(_diskCache));
    } catch (_) {
      // solo la cache va persa, non la ricerca già fatta
    }
  }

  @override
  Future<GameLookupMatch?> searchGame(String title, {bool requireCloseMatch = false}) async {
    final normalizedQuery = _normalize(title);
    if (normalizedQuery.isEmpty) return null;

    final cache = await _loadDiskCache();
    if (cache.containsKey(normalizedQuery)) {
      final cached = cache[normalizedQuery];
      if (cached == null) return null;
      return GameLookupMatch(name: cached['name'] as String, coverUrl: cached['coverUrl'] as String?);
    }

    try {
      final uri = Uri.parse(
        'https://store.steampowered.com/api/storesearch'
        '?term=${Uri.encodeQueryComponent(title)}&l=english&cc=US',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        await _rememberMiss(normalizedQuery);
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        await _rememberMiss(normalizedQuery);
        return null;
      }

      Map<String, dynamic>? best;
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final name = map['name'] as String?;
        if (name == null) continue;
        if (_normalize(name) == normalizedQuery) {
          best = map;
          break;
        }
        best ??= map;
      }

      if (best == null) {
        await _rememberMiss(normalizedQuery);
        return null;
      }

      final bestName = best['name'] as String;
      final normalizedBest = _normalize(bestName);
      final isExactMatch = normalizedBest == normalizedQuery;
      final isContainmentMatch =
          normalizedBest.contains(normalizedQuery) || normalizedQuery.contains(normalizedBest);

      // Per lo scanner profondo (requireCloseMatch) il titolo arriva da
      // un'euristica sul nome di una cartella — è un'ipotesi, non un fatto
      // già confermato. Per questo qui si accetta SOLO un match esatto
      // (dopo normalizzazione): un semplice "contiene" è troppo permissivo
      // con nomi brevi/generici e produce falsi positivi (cartelle che non
      // sono affatto giochi, ma il cui nome assomiglia a un titolo Steam
      // oscuro). Per Battle.net/EA/Ubisoft invece il titolo arriva già dal
      // registro di Windows (fonte affidabile), quindi qui basta un
      // contenimento — ma comunque MAI accettare alla cieca il primo
      // risultato se non assomiglia affatto alla query.
      final acceptable = requireCloseMatch ? isExactMatch : (isExactMatch || isContainmentMatch);

      if (!acceptable) {
        await _rememberMiss(normalizedQuery);
        return null;
      }

      final appId = best['id'];
      final coverUrl = appId != null
          ? 'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/library_600x900.jpg'
          : null;

      final match = GameLookupMatch(name: bestName, coverUrl: coverUrl);
      cache[normalizedQuery] = {'name': match.name, 'coverUrl': match.coverUrl};
      await _saveDiskCache();
      return match;
    } catch (_) {
      return null;
    }
  }

  Future<void> _rememberMiss(String normalizedQuery) async {
    final cache = await _loadDiskCache();
    cache[normalizedQuery] = null;
    await _saveDiskCache();
  }

  String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
