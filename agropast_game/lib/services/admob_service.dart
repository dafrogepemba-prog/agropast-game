import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ============================================================
// AdMob Service — Rewarded Ads (PRODUCTION)
// App ID     : ca-app-pub-4115564366785475~5279911679
// Ad Unit ID : ca-app-pub-4115564366785475/9740112422
//
// Règles Google AdMob strictement respectées :
// - Récompense UNIQUEMENT via onUserEarnedReward
// - Pub fermée avant la fin → PAS de récompense
// - Aucune incitation au clic sur la publicité
// - Pré-chargement dès l'ouverture du jeu pour UX fluide
// ============================================================

class AdMobService {
  // ── IDs de production ──────────────────────────────────
  static const String _appId =
      'ca-app-pub-4115564366785475~5279911679';

  static const String _rewardedAdUnitId =
      'ca-app-pub-4115564366785475/9740112422';

  // ── État interne ───────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => _isLoaded && !kIsWeb;
  bool get isShowing => _isShowing;

  // ── Initialisation SDK (appelé dans main.dart) ─────────
  static Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    debugPrint('[AdMob] SDK initialized — App: $_appId');
  }

  // ── Pré-chargement de la Rewarded Ad ───────────────────
  // À appeler dès l'ouverture de game_screen pour avoir la pub prête
  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (kIsWeb) return; // Pas de pub sur web

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoaded   = true;
          debugPrint('[AdMob] Rewarded Ad loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoaded   = false;
          debugPrint('[AdMob] Failed to load: ${error.message}');
          onFailed?.call();
          // Retry après 30 secondes
          Future.delayed(const Duration(seconds: 30), () {
            loadRewardedAd(onLoaded: onLoaded);
          });
        },
      ),
    );
  }

  // ── Affichage de la Rewarded Ad ────────────────────────
  //
  // RÈGLE ADMOB STRICTE (§ Rewarded ads policy) :
  // • La récompense n'est accordée QUE dans onUserEarnedReward
  // • onAdDismissedFullScreenContent ne donne PAS de récompense
  //   si onUserEarnedReward n'a pas encore été appelé
  // • Aucune récompense partielle
  //
  void showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    if (kIsWeb || !_isLoaded || _rewardedAd == null) {
      onAdFailedToShow?.call();
      return;
    }

    bool _rewardGranted = false; // garde-fou anti-double-récompense
    _isShowing = true;
    _isLoaded  = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isShowing  = false;
        // Si la vidéo a été fermée SANS que onUserEarnedReward soit appelé
        // → pas de récompense (règle AdMob)
        if (!_rewardGranted) {
          onAdDismissedWithoutReward?.call();
        }
        // Précharger la prochaine pub immédiatement
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isShowing  = false;
        debugPrint('[AdMob] Failed to show: ${error.message}');
        onAdFailedToShow?.call();
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // ✅ SEUL endroit où la récompense est accordée
        // Déclenché par Google uniquement si la vidéo est vue en entier
        _rewardGranted = true;
        onUserEarnedReward(reward.amount.toInt(), reward.type);
        debugPrint('[AdMob] onUserEarnedReward: ${reward.amount} ${reward.type}');
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isLoaded   = false;
    _isShowing  = false;
  }
}
