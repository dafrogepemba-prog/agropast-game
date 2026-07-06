import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// AdMob Service — Rewarded Ads
// Conforme aux règles Google AdMob :
// - La récompense ne se déclenche QUE via onUserEarnedReward
// - Si l'utilisateur ferme avant la fin → PAS de récompense
// - Aucune incitation au clic sur la pub
// ============================================================

// Import conditionnel : AdMob uniquement sur Android/iOS
// Sur web : stub qui ne fait rien
class AdMobService {
  // IDs de test Google (à remplacer par les vrais IDs en production)
  // Android test ID : ca-app-pub-3940256099942544/5224354917
  static const String rewardedAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/5224354917';

  // TODO: Remplacer par ton vrai Ad Unit ID après approbation AdMob
  // static const String rewardedAdUnitIdProd = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';

  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => _isLoaded && !kIsWeb;
  bool get isShowing => _isShowing;

  // ---- Initialisation ----------------------------------------
  static Future<void> init() async {
    if (kIsWeb) return;
    // Sur Android/iOS : MobileAds.instance.initialize()
    // Activé quand google_mobile_ads est réintégré pour le build Android
    debugPrint('[AdMob] Initialized (mobile mode)');
  }

  // ---- Chargement de la Rewarded Ad --------------------------
  // Appelé dès que l'écran de jeu est chargé pour avoir la pub prête
  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (kIsWeb) {
      debugPrint('[AdMob] Web : rewarded ads not supported');
      return;
    }

    // Sur Android (quand google_mobile_ads est actif) :
    // RewardedAd.load(
    //   adUnitId: rewardedAdUnitIdAndroid,
    //   request: const AdRequest(),
    //   rewardedAdLoadCallback: RewardedAdLoadCallback(
    //     onAdLoaded: (ad) {
    //       _rewardedAd = ad;
    //       _isLoaded = true;
    //       onLoaded?.call();
    //     },
    //     onAdFailedToLoad: (error) {
    //       _isLoaded = false;
    //       onFailed?.call();
    //       debugPrint('[AdMob] Failed to load: $error');
    //     },
    //   ),
    // );

    // Simulation pour test (web/debug)
    Future.delayed(const Duration(milliseconds: 800), () {
      _isLoaded = true;
      onLoaded?.call();
      debugPrint('[AdMob] Rewarded Ad loaded (simulation)');
    });
  }

  // ---- Affichage de la Rewarded Ad ---------------------------
  // RÈGLE ADMOB STRICTE :
  // La récompense ne se déclenche QUE dans onUserEarnedReward.
  // Si l'utilisateur ferme avant la fin → onDismissed sans récompense.
  void showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    if (kIsWeb || !_isLoaded) {
      onAdFailedToShow?.call();
      debugPrint('[AdMob] Cannot show ad: not loaded or web platform');
      return;
    }

    _isShowing = true;
    _isLoaded  = false;

    // Sur Android (quand google_mobile_ads est actif) :
    // _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
    //   onAdDismissedFullScreenContent: (ad) {
    //     ad.dispose();
    //     _isShowing = false;
    //     // Ne rien faire ici — la récompense vient de onUserEarnedReward
    //     // Si onUserEarnedReward n'a pas été appelé → pas de récompense
    //     loadRewardedAd(); // Précharger la suivante
    //   },
    //   onAdFailedToShowFullScreenContent: (ad, error) {
    //     ad.dispose();
    //     _isShowing = false;
    //     onAdFailedToShow?.call();
    //   },
    // );
    // _rewardedAd!.show(
    //   onUserEarnedReward: (ad, reward) {
    //     // SEUL endroit où la récompense est accordée
    //     onUserEarnedReward(reward.amount.toInt(), reward.type);
    //   },
    // );

    // Simulation pour test : l'utilisateur regarde la pub complète
    Future.delayed(const Duration(seconds: 2), () {
      _isShowing = false;
      // Simule onUserEarnedReward (la vraie récompense AdMob)
      onUserEarnedReward(50, 'pieces_or');
      debugPrint('[AdMob] onUserEarnedReward fired (simulation)');
      // Recharger pour la prochaine fois
      loadRewardedAd();
    });
  }

  void dispose() {
    _isLoaded  = false;
    _isShowing = false;
  }
}
