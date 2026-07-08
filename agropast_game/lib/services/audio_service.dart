// ============================================================
// audio_service.dart — BGM + SFX Parcours Quotidien (P1)
// 2 instances AudioPlayer distinctes : BGM loop + SFX one-shot
// Web : BGM démarrée seulement après le premier tap utilisateur
//       (contrainte autoplay policy des navigateurs)
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // ── Deux instances séparées pour éviter les conflits ─────
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  bool _bgmStarted  = false;
  bool _sfxReady    = false;

  // ── Fichiers audio (à placer dans assets/sounds/) ────────
  // Budget total < 500 Ko (mono, 64-96 kbps)
  static const String _bgmFile    = 'sounds/bgm_parcours.mp3';
  static const String _sfxFile    = 'sounds/sfx_arrosage.mp3';
  static const String _jingleFile = 'sounds/jingle_recolte.mp3';

  bool get bgmStarted => _bgmStarted;

  // ── Précharger le SFX pour latence < 50ms au premier tap ─
  Future<void> preload() async {
    try {
      await _sfx.setSource(AssetSource(_sfxFile));
      _sfxReady = true;
    } catch (_) {
      // Fichier absent → mode silencieux (Req. 7.6)
    }
  }

  // ── Démarrer la BGM en boucle ────────────────────────────
  // Sur web : appeler APRÈS le premier tap (autoplay policy)
  // Sur Android : appeler dans initState
  Future<void> startBgm() async {
    if (_bgmStarted) return;
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.4);
      await _bgm.play(AssetSource(_bgmFile));
      _bgmStarted = true;
    } catch (_) {}
  }

  // ── Jouer SFX arrosoir (one-shot, sans interrompre BGM) ──
  Future<void> playSfxArrosage() async {
    try {
      if (_sfxReady) {
        await _sfx.stop();
        await _sfx.play(AssetSource(_sfxFile));
      }
    } catch (_) {}
  }

  // ── Jingle à 100% : baisse BGM 2s puis retour ────────────
  Future<void> playJingleRecolte() async {
    try {
      // Baisser le volume de la BGM
      await _bgm.setVolume(0.1);
      // Jouer le jingle via le SFX player
      await _sfx.play(AssetSource(_jingleFile));
      // Remonter le volume après 2s
      await Future.delayed(const Duration(seconds: 2));
      await _bgm.setVolume(0.4);
    } catch (_) {}
  }

  // ── Pause / reprise (quand pub AdMob s'affiche) ───────────
  Future<void> pauseBgm()  async => _bgm.pause();
  Future<void> resumeBgm() async => _bgm.resume();

  // ── Arrêt et libération des ressources ───────────────────
  Future<void> dispose() async {
    await _bgm.stop();
    await _sfx.stop();
    await _bgm.dispose();
    await _sfx.dispose();
    _bgmStarted = false;
  }
}
