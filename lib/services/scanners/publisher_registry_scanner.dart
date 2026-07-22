import '../../models/game.dart';
import '../game_lookup_service.dart';
import 'registry_scan_utils.dart';

/// Scanner generico per i launcher che non hanno un catalogo locale
/// facilmente leggibile (Battle.net usa un database binario proprietario,
/// EA App ed Ubisoft Connect hanno formati altrettanto poco documentati).
///
/// L'approccio comune: quasi tutti questi launcher registrano comunque
/// ogni gioco installato nella lista standard "Programmi e funzionalità"
/// di Windows (obbligatorio per apparire lì ed essere disinstallabili),
/// quindi si legge da lì invece di provare a decodificare i formati
/// interni di ciascun launcher.
///
/// La cover non ha un CDN diretto legato a un ID come per Steam/GOG/Epic,
/// quindi si usa IGDB (se l'utente ha configurato le credenziali) cercando
/// per titolo — qui il match può essere permissivo perché il titolo viene
/// già da una fonte affidabile (il registro di Windows), non da un
/// riconoscimento incerto come nello scanner profondo.
class PublisherRegistryScanner {
  PublisherRegistryScanner({
    required this.source,
    required this.idPrefix,
    required this.publisherMatches,
    required this.lookupService,
  });

  final GameSource source;
  final String idPrefix;
  final List<String> publisherMatches;
  final GameLookupService? lookupService;

  Future<List<Game>> scan() async {
    final entries = scanUninstallEntries(publisherMatches);
    final games = <Game>[];

    for (final entry in entries) {
      final executablePath = resolveExecutable(entry);
      if (executablePath == null) continue;

      String? coverImagePath;
      if (lookupService != null) {
        final match = await lookupService!.searchGame(entry.displayName);
        coverImagePath = match?.coverUrl;
      }

      games.add(Game(
        id: '${idPrefix}_${entry.displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
        title: entry.displayName,
        executablePath: executablePath,
        source: source,
        coverImagePath: coverImagePath,
      ));
    }

    return games;
  }
}
