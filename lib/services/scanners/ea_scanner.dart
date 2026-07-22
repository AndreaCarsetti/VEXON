import '../../models/game.dart';
import '../game_lookup_service.dart';
import 'publisher_registry_scanner.dart';

class EaScanner {
  EaScanner({this.lookupService});
  final GameLookupService? lookupService;

  Future<List<Game>> scan() {
    return PublisherRegistryScanner(
      source: GameSource.ea,
      idPrefix: 'ea',
      // Alcuni titoli EA registrano "Electronic Arts", altri il nome dello
      // studio interno (es. "EA DICE", "EA Sports") — si controllano
      // entrambe le varianti più comuni.
      publisherMatches: ['Electronic Arts', 'EA Games', 'EA Sports'],
      lookupService: lookupService,
    ).scan();
  }
}
