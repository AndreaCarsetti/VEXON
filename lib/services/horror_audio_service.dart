import 'package:audioplayers/audioplayers.dart';

/// Servizio per la riproduzione del suono sincronizzato con l'apparizione
/// del logo alla fine della boot sequence.
class HorrorAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _soundAvailable = true;

  static const String _logoImpactFile =
      'audio/dragon-studio-dramatic-thud-reverb-478375.mp3';

  static Future<void> initialize() async {
    try {
      await _player.setSource(AssetSource(_logoImpactFile));
    } catch (e) {
      _soundAvailable = false;
      print('[HorrorAudioService] Audio file not found, continuing without sound');
    }
  }

  /// Riproduce il suono dell'impatto/apparizione del logo.
  static Future<void> playLogoImpact() async {
    if (!_soundAvailable) return;
    try {
      await _player.play(AssetSource(_logoImpactFile), volume: 0.85);
    } catch (e) {
      print('[HorrorAudioService] Error playing logo impact: $e');
    }
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static Future<void> dispose() async {
    await _player.release();
  }
}
