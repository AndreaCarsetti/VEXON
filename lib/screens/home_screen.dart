import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../services/game_boost_service.dart';
import '../services/game_scanner_service.dart';
import '../services/hardware_monitor_service.dart';
import '../services/manual_games_store.dart';
import '../theme/vexon_colors.dart';
import '../widgets/add_manual_game_dialog.dart';
import '../widgets/game_boost_transition.dart';
import '../widgets/game_card.dart';
import '../widgets/hardware_hud.dart';
import '../widgets/particle_background.dart';
import '../widgets/staggered_fade_in.dart';
import '../widgets/top_bar.dart';
import '../widgets/vexon_loading_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scanner = GameScannerService();
  final _manualGamesStore = ManualGamesStore();
  late final HardwareMonitorService _hardwareService;

  List<Game> _games = [];
  String _searchQuery = '';
  bool _loading = true;
  bool _gameModeActive = false;
  HardwareStats? _latestStats;
  bool _showBoostTransition = false;

  // Storico "rolling" per i grafici sparkline dell'HUD — 40 campioni a 1
  // ogni secondo = circa gli ultimi 40 secondi, come nel Task Manager.
  static const _historyLength = 40;
  final List<double> _cpuHistory = [];
  final List<double> _gpuHistory = [];
  final List<double> _ramHistory = [];

  @override
  void initState() {
    super.initState();
    _hardwareService = HardwareMonitorService.native();
    _hardwareService.statsStream.listen((stats) {
      if (!mounted) return;
      setState(() {
        _latestStats = stats;
        _pushHistory(_cpuHistory, stats.cpuUsagePercent);
        if (stats.gpuUsagePercent != null) _pushHistory(_gpuHistory, stats.gpuUsagePercent!);
        _pushHistory(_ramHistory, stats.ramUsagePercent);
      });
    });
    _loadGames();
  }

  void _pushHistory(List<double> history, double value) {
    history.add(value);
    if (history.length > _historyLength) history.removeAt(0);
  }

  Future<void> _loadGames() async {
    final scannedGames = await _scanner.scanAll();
    final manualGames = await _manualGamesStore.load();
    if (mounted) {
      setState(() {
        _games = [...scannedGames, ...manualGames];
        _loading = false;
      });
    }
  }

  Future<void> _openAddManualGameDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddManualGameDialog(),
    );
    if (result == null) return;

    await _manualGamesStore.add(
      title: result['title']!,
      executablePath: result['executablePath']!,
    );
    await _loadGames();
  }

  Future<void> _confirmRemoveManualGame(Game game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VexonColors.surface,
        title: const Text('Rimuovere questo gioco?', style: TextStyle(color: VexonColors.textPrimary)),
        content: Text(
          '"${game.title}" verrà rimosso dalla libreria (solo la voce in VEXON, non i file del gioco).',
          style: const TextStyle(color: VexonColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla', style: TextStyle(color: VexonColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VexonColors.critical,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _manualGamesStore.remove(game.id);
      await _loadGames();
    }
  }

  /// Avvia un gioco. Per Steam usa il protocollo steam://rungameid/<appid>
  /// invece di eseguire direttamente il binario nella cartella
  /// d'installazione: molti giochi Steam richiedono di passare dal client
  /// (DRM, anticheat, overlay, achievements) e lanciarli "a mano" spesso
  /// non funziona o li avvia senza queste funzionalità. Per Epic e per i
  /// giochi aggiunti manualmente, invece, executablePath è già un percorso
  /// diretto all'eseguibile, quindi lo lanciamo così com'è.
  Future<void> _launchGame(Game game) async {
    try {
      if (game.source == GameSource.steam && game.steamAppId != null) {
        // 'start' è un comando interno di cmd.exe, non un eseguibile: va
        // invocato tramite cmd /c. La stringa vuota dopo start è il titolo
        // della finestra (richiesto quando l'URL contiene ':').
        await Process.start(
          'cmd',
          ['/c', 'start', '', 'steam://rungameid/${game.steamAppId}'],
          mode: ProcessStartMode.detached,
        );
        return;
      }

      if (game.executablePath.isEmpty) {
        throw const FileSystemException('Percorso eseguibile mancante');
      }

      await Process.start(
        game.executablePath,
        [],
        mode: ProcessStartMode.detached,
        workingDirectory: p.dirname(game.executablePath),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile avviare "${game.title}": $e')),
      );
    }
  }

  void _toggleGameMode(bool active) {
    setState(() {
      _gameModeActive = active;
      _showBoostTransition = true;
    });
    // Fire-and-forget: il servizio gestisce già i propri errori
    // internamente (es. powercfg non disponibile) senza propagarli qui,
    // così il pulsante resta sempre reattivo indipendentemente dall'esito.
    if (active) {
      GameBoostService.enable();
    } else {
      GameBoostService.disable();
    }
  }

  List<Game> get _filteredGames {
    if (_searchQuery.isEmpty) return _games;
    return _games
        .where((g) => g.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _hardwareService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VexonColors.background,
      appBar: TopBar(
        gameModeActive: _gameModeActive,
        onGameModeToggle: _toggleGameMode,
        onSearchChanged: (q) => setState(() => _searchQuery = q),
        onAddGame: _openAddManualGameDialog,
      ),
      body: ParticleBackground(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const VexonLoadingIndicator(label: 'Scansione libreria in corso…')
                  : _filteredGames.isEmpty
                      ? _EmptyLibraryState(hasQuery: _searchQuery.isNotEmpty)
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredGames.length,
                          itemBuilder: (context, i) {
                            final game = _filteredGames[i];
                            return StaggeredFadeIn(
                              index: i,
                              child: GameCard(
                                game: game,
                                onLaunch: () => _launchGame(game),
                                // La rimozione (tenendo premuto) ha senso
                                // solo per le voci aggiunte manualmente —
                                // quelle rilevate da Steam/Epic restano
                                // gestite dai rispettivi launcher.
                                onLongPress: game.source == GameSource.manual
                                    ? () => _confirmRemoveManualGame(game)
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: HardwareHud(
                stats: _latestStats,
                cpuHistory: _cpuHistory,
                gpuHistory: _gpuHistory,
                ramHistory: _ramHistory,
              ),
            ),
            if (_showBoostTransition)
              Positioned.fill(
                child: GameBoostTransition(
                  activating: _gameModeActive,
                  onCompleted: () {
                    if (mounted) setState(() => _showBoostTransition = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyLibraryState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videogame_asset_outlined,
              size: 56, color: VexonColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            hasQuery
                ? 'Nessun gioco trovato con questo nome'
                : 'Nessun gioco rilevato automaticamente.\nSe hai Steam o Epic Games installati su un percorso non standard,\npuoi aggiungere i giochi manualmente dal pulsante in alto.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VexonColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
