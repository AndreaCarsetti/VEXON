import 'package:audioplayers/audioplayers.dart';

/// Servizio per la riproduzione di suoni sincronizzati con l'animazione
/// del boot sequence. Usa "dragon-studio-dramatic-thud-reverb-478375.mp3"
/// per tutte le fasi (suono versatile per horror).
class HorrorAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _soundsAvailable = true;
  static const String _audioFile = 'audio/dragon-studio-dramatic-thud-reverb-478375.mp3';

  /// Suoni mappati al timing dell'animazione (in millisecondi dal start)
  static const Map<String, int> _soundTimings = {
    'eyes_open': 150,       // Occhi che si aprono
    'creature_approach': 400, // Creature che si avvicinano
    'chaos_peak': 950,      // Picco del caos
    'white_flash': 1950,    // Flash bianco finale
  };

  /// Pre-cache del suono all'avvio
  static Future<void> initialize() async {
    try {
      // Prova a caricare il suono; se non esiste, disabilita silenziosamente
      await _player.setSource(AssetSource(_audioFile));
    } catch (e) {
      _soundsAvailable = false;
      print('[HorrorAudioService] Audio file not found, continuing without sound');
    }
  }

  /// Riproduce il suono (senza preload, ogni volta)
  static Future<void> playSound(String soundKey) async {
    if (!_soundsAvailable) return;

    try {
      // Riproduci il suono con volume appropriato
      await _player.play(
        AssetSource(_audioFile),
        volume: 0.85,
      );
    } catch (e) {
      print('[HorrorAudioService] Error playing $soundKey: $e');
    }
  }

  /// Ottiene il timing (ms) per un suono
  static int? getTimingForSound(String key) {
    return _soundTimings[key];
  }

  /// Arresta la riproduzione
  static Future<void> stop() async {
    await _player.stop();
  }

  /// Pulizia
  static Future<void> dispose() async {
    await _player.release();
  }
}

