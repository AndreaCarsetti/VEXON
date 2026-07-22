import '../models/game.dart';
import 'game_lookup_service.dart';
import 'scanners/battlenet_scanner.dart';
import 'scanners/ea_scanner.dart';
import 'scanners/epic_scanner.dart';
import 'scanners/gog_scanner.dart';
import 'scanners/steam_scanner.dart';
import 'scanners/ubisoft_scanner.dart';

/// Scansiona le librerie di gioco installate sul PC su tutti i launcher
/// supportati: Steam, Epic Games, GOG, Battle.net, EA App e Ubisoft
/// Connect. Ogni piattaforma ha uno scanner dedicato in `scanners/` — qui
/// ci si limita ad aggregare i risultati.
///
/// [lookupService], se passato, viene usato dagli scanner che non hanno un
/// CDN cover diretto (Battle.net, EA, Ubisoft) per recuperare la copertina
/// cercando per titolo — in pratica Steam Store Search. Senza, quei giochi
/// vengono comunque rilevati correttamente: restano solo senza cover
/// (placeholder).
class GameScannerService {
  GameScannerService({GameLookupService? lookupService}) : _lookupService = lookupService;

  final GameLookupService? _lookupService;

  Future<List<Game>> scanAll() async {
    final games = <Game>[];

    // Steam ed Epic hanno un catalogo locale leggibile direttamente
    // (file .acf / manifest .item), quindi girano sempre, IGDB o meno.
    games.addAll(await SteamScanner().scan());
    games.addAll(await EpicScanner().scan());
    games.addAll(await GogScanner().scan());

    games.addAll(await BattlenetScanner(lookupService: _lookupService).scan());
    games.addAll(await EaScanner(lookupService: _lookupService).scan());
    games.addAll(await UbisoftScanner(lookupService: _lookupService).scan());

    return games;
  }
}
