// ============================================================
// audio_service.dart — BGM + SFX Parcours Quotidien
// Compatible Flutter Web (6.x) + Android
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  bool _bgmStarted = false;

  static const String _bgmFile    = 'sounds/bgm_parcours.mp3';
  static const String _sfxFile    = 'sounds/sfx_arrosage.mp3';
  static const String _jingleFile = 'sounds/jingle_recolte.mp3';

  bool get bgmStarted => _bgmStarted;

  // ── Précharger les sons ───────────────────────────────────
  Future<void> preload() async {
    try {
      await _sfx.setSource(AssetSource(_sfxFile));
    } catch (_) {}
  }

  // ── Démarrer BGM (web : après premier tap) ────────────────
  Future<void> startBgm() async {
    if (_bgmStarted) return;
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.35);
      await _bgm.play(AssetSource(_bgmFile));
      _bgmStarted = true;
    } catch (_) {}
  }

  // ── SFX tap arrosoir ─────────────────────────────────────
  // Sur web : nouveau AudioPlayer à chaque tap car
  // audioplayers 6.x ne supporte pas stop+replay fiable sur web
  Future<void> playSfxArrosage() async {
    try {
      if (kIsWeb) {
        final p = AudioPlayer()..setVolume(0.8);
        await p.play(AssetSource(_sfxFile));
        Future.delayed(const Duration(seconds: 3), () => p.dispose());
      } else {
        await _sfx.stop();
        await _sfx.play(AssetSource(_sfxFile));
      }
    } catch (_) {}
  }

  // ── Jingle récolte 100% ───────────────────────────────────
  Future<void> playJingleRecolte() async {
    try {
      await _bgm.setVolume(0.1);
      final p = AudioPlayer();
      await p.play(AssetSource(_jingleFile));
      Future.delayed(const Duration(seconds: 3), () async {
        await p.dispose();
        await _bgm.setVolume(0.35);
      });
    } catch (_) {}
  }

  Future<void> pauseBgm()  async { try { await _bgm.pause();  } catch (_) {} }
  Future<void> resumeBgm() async { try { await _bgm.resume(); } catch (_) {} }

  Future<void> dispose() async {
    try {
      await _bgm.stop();
      await _sfx.stop();
      await _bgm.dispose();
      await _sfx.dispose();
      _bgmStarted = false;
    } catch (_) {}
  }
}
