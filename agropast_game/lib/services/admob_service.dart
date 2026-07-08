import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// AdMob Service — Production
// App ID     : ca-app-pub-4115564366785475~5279911679
// Ad Unit ID : ca-app-pub-4115564366785475/9740112422
//
// SDK google_mobile_ads compilé via GitHub Actions CI (Ubuntu)
// Web : simulation 2s — AdSense H5 gère les pubs web
// ============================================================

// Imports conditionnels AdMob (mobile uniquement)
// ignore: uri_does_not_exist
import 'admob_stub.dart'
    if (dart.library.io) 'admob_real.dart';

class AdMobService {
  static const String appId          = 'ca-app-pub-4115564366785475~5279911679';
  static const String rewardedAdUnit = 'ca-app-pub-4115564366785475/9740112422';

  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => _isLoaded && !kIsWeb;
  bool get isShowing => _isShowing;

  static Future<void> init() async {
    if (kIsWeb) return;
    await AdMobImpl.initialize();
    debugPrint('[AdMob] SDK initialisé');
  }

  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (kIsWeb) return;
    AdMobImpl.loadRewarded(
      adUnitId: rewardedAdUnit,
      onLoaded: () {
        _isLoaded = true;
        onLoaded?.call();
        debugPrint('[AdMob] Ad prête');
      },
      onFailed: () {
        _isLoaded = false;
        onFailed?.call();
        Future.delayed(const Duration(seconds: 30), () => loadRewardedAd(onLoaded: onLoaded));
      },
    );
  }

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

    AdMobImpl.showRewarded(
      onEarned: (amount, type) {
        _isShowing = false;
        onUserEarnedReward(amount, type);
        loadRewardedAd();
      },
      onDismissed: () {
        _isShowing = false;
        onAdDismissedWithoutReward?.call();
        loadRewardedAd();
      },
      onFailed: () {
        _isShowing = false;
        onAdFailedToShow?.call();
      },
    );
  }

  void dispose() {
    AdMobImpl.dispose();
    _isLoaded  = false;
    _isShowing = false;
  }
}
