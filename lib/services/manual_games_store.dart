import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/game.dart';

/// Gestisce i giochi aggiunti manualmente dall'utente — la "rete di
/// sicurezza" per quando lo scanner automatico (Steam/Epic) non rileva
/// qualcosa, per qualunque motivo: launcher non supportato, eseguibile
/// standalone, o un bug nello scanner stesso.
///
/// Persistiti in un piccolo file JSON nella cartella dati dell'app
/// (`getApplicationSupportDirectory`), così restano tra un avvio e l'altro
/// — niente bisogno di un vero database per una lista così semplice.
class ManualGamesStore {
  static const _fileName = 'manual_games.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<Game>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;

      return list.map((entry) {
        final map = entry as Map<String, dynamic>;
        return Game(
          id: 'manual_${map['id']}',
          title: map['title'] as String,
          executablePath: map['executablePath'] as String,
          source: GameSource.manual,
        );
      }).toList();
    } catch (_) {
      // File assente, corrotto, o con un formato inatteso: meglio
      // ripartire da una lista vuota che far crashare l'app all'avvio.
      return [];
    }
  }

  Future<void> add({required String title, required String executablePath}) async {
    final games = await load();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    games.add(Game(
      id: 'manual_$id',
      title: title,
      executablePath: executablePath,
      source: GameSource.manual,
    ));
    await _save(games);
  }

  /// [gameId] è l'id completo del gioco (es. "manual_1234567890"), lo
  /// stesso già usato nell'oggetto `Game` — non serve ripulirlo qui.
  Future<void> remove(String gameId) async {
    final games = await load();
    games.removeWhere((g) => g.id == gameId);
    await _save(games);
  }

  Future<void> _save(List<Game> games) async {
    final file = await _file();
    final list = games
        .map((g) => {
              'id': g.id.replaceFirst('manual_', ''),
              'title': g.title,
              'executablePath': g.executablePath,
            })
        .toList();
    await file.writeAsString(jsonEncode(list));
  }
}
