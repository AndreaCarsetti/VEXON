import '../../models/game.dart';
import '../game_lookup_service.dart';
import 'publisher_registry_scanner.dart';

class UbisoftScanner {
  UbisoftScanner({this.lookupService});
  final GameLookupService? lookupService;

  Future<List<Game>> scan() {
    return PublisherRegistryScanner(
      source: GameSource.ubisoft,
      idPrefix: 'ubisoft',
      publisherMatches: ['Ubisoft'],
      lookupService: lookupService,
    ).scan();
  }
}
