import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// AdMob Service — Rewarded Ads
// App ID     : ca-app-pub-4115564366785475~5279911679
// Ad Unit ID : ca-app-pub-4115564366785475/9740112422
//
// SDK google_mobile_ads activé via GitHub Actions CI (build Android)
// En local web : simulation — récompense après 2s
// ============================================================

class AdMobService {
  static const String appId         = 'ca-app-pub-4115564366785475~5279911679';
  static const String rewardedAdUnit = 'ca-app-pub-4115564366785475/9740112422';

  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => _isLoaded && !kIsWeb;
  bool get isShowing => _isShowing;

  // ── Init SDK (appelé dans main.dart) ────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;
    // MobileAds.instance.initialize() — activé dans le build CI Android
    debugPrint('[AdMob] Init — App: $appId');
  }

  // ── Charger la pub récompensée ───────────────────────────
  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (kIsWeb) return;

    // En mode CI Android avec SDK actif :
    // RewardedAd.load(adUnitId: rewardedAdUnit, ...)
    // Pour l'instant simulation (SDK commenté)
    Future.delayed(const Duration(milliseconds: 800), () {
      _isLoaded = true;
      onLoaded?.call();
      debugPrint('[AdMob] Rewarded Ad ready');
    });
  }

  // ── Afficher la pub récompensée ──────────────────────────
  // RÈGLE ADMOB : récompense UNIQUEMENT via onUserEarnedReward
  void showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    if (kIsWeb || !_isLoaded) {
      onAdFailedToShow?.call();
      return;
    }

    _isShowing = true;
    _isLoaded  = false;

    // Simulation 2s (remplacé par vrai SDK dans CI) :
    Future.delayed(const Duration(seconds: 2), () {
      _isShowing = false;
      onUserEarnedReward(50, 'pieces_or');
      debugPrint('[AdMob] onUserEarnedReward (simulation)');
      loadRewardedAd();
    });
  }

  void dispose() {
    _isLoaded  = false;
    _isShowing = false;
  }
}
