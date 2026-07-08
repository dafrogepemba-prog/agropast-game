import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ============================================================
// AdMob Mobile — Android/iOS production
// App ID     : ca-app-pub-4115564366785475~5279911679
// Ad Unit ID : ca-app-pub-4115564366785475/9740112422
// ============================================================

class AdMobService {
  static const String appId          = 'ca-app-pub-4115564366785475~5279911679';
  static const String rewardedAdUnit = 'ca-app-pub-4115564366785475/9740112422';

  RewardedAd? _rewardedAd;
  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => _isLoaded && !kIsWeb;
  bool get isShowing => _isShowing;

  // ── Init SDK ────────────────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    debugPrint('[AdMob] SDK initialisé — $appId');
  }

  // ── Charger la pub ──────────────────────────────────────
  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (kIsWeb) return;

    RewardedAd.load(
      adUnitId: rewardedAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoaded   = true;
          debugPrint('[AdMob] Rewarded Ad chargée');
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoaded   = false;
          debugPrint('[AdMob] Echec chargement: ${error.message}');
          onFailed?.call();
          // Retry après 30s
          Future.delayed(const Duration(seconds: 30),
              () => loadRewardedAd(onLoaded: onLoaded));
        },
      ),
    );
  }

  // ── Afficher la pub ─────────────────────────────────────
  // RÈGLE ADMOB : récompense UNIQUEMENT via onUserEarnedReward
  void showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    if (kIsWeb || !_isLoaded || _rewardedAd == null) {
      onAdFailedToShow?.call();
      return;
    }

    bool _rewarded = false;
    _isShowing = true;
    _isLoaded  = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isShowing  = false;
        // Pub fermée SANS récompense → pas de points
        if (!_rewarded) onAdDismissedWithoutReward?.call();
        loadRewardedAd(); // précharger la suivante
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isShowing  = false;
        debugPrint('[AdMob] Echec affichage: ${error.message}');
        onAdFailedToShow?.call();
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // ✅ SEUL callback officiel AdMob qui accorde la récompense
        // Déclenché UNIQUEMENT si la vidéo a été vue en entier
        _rewarded = true;
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
