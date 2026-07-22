import '../../models/game.dart';
import '../game_lookup_service.dart';
import 'publisher_registry_scanner.dart';

class BattlenetScanner {
  BattlenetScanner({this.lookupService});
  final GameLookupService? lookupService;

  Future<List<Game>> scan() {
    return PublisherRegistryScanner(
      source: GameSource.battlenet,
      idPrefix: 'battlenet',
      // I giochi Blizzard registrano publisher leggermente diversi a
      // seconda del titolo/versione installer ("Blizzard Entertainment"
      // è però costante in tutti quelli osservati).
      publisherMatches: ['Blizzard Entertainment'],
      lookupService: lookupService,
    ).scan();
  }
}
