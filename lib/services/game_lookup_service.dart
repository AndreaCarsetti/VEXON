/// Risultato di una ricerca gioco-per-titolo, indipendente dal provider
/// usato per trovarlo (IGDB o Steam Store Search).
class GameLookupMatch {
  final String name;
  final String? coverUrl;
  const GameLookupMatch({required this.name, this.coverUrl});
}

/// Interfaccia comune per i provider usati a "confermare" un titolo e
/// recuperarne la cover: IGDB (serve una chiave gratuita, copre
/// praticamente ogni gioco) e Steam Store Search (nessuna configurazione,
/// ma conosce solo giochi presenti su Steam). Scanner e servizi che
/// necessitano di riconoscere un titolo dipendono da questa interfaccia,
/// non da un'implementazione specifica — così passare da un provider
/// all'altro (o disattivarli del tutto) non richiede toccare il resto del
/// codice.
abstract class GameLookupService {
  /// Cerca [title]. Con [requireCloseMatch] a true il confronto è
  /// stringente (usato dallo scanner profondo, dove un match debole
  /// rischia di aggiungere un gioco sbagliato alla libreria); a false è
  /// permissivo (usato per le cover di giochi già identificati con
  /// certezza da un launcher).
  Future<GameLookupMatch?> searchGame(String title, {bool requireCloseMatch = false});
}
