import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// AdMob Service — Production
// App ID     : ca-app-pub-4115564366785475~5279911679
// Ad Unit ID : ca-app-pub-4115564366785475/9740112422
// ============================================================

class AdMobService {
  static const String appId          = 'ca-app-pub-4115564366785475~5279911679';
  static const String rewardedAdUnit = 'ca-app-pub-4115564366785475/9740112422';

  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => _isLoaded && !kIsWeb;
  bool get isShowing => _isShowing;

  static Future<void> init() async {
    debugPrint('[AdMob] Init — $appId');
  }

  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (kIsWeb) return;
    // Simulation — SDK activé après validation APK
    Future.delayed(const Duration(milliseconds: 800), () {
      _isLoaded = true;
      onLoaded?.call();
    });
  }

  void showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    if (!_isLoaded) {
      onAdFailedToShow?.call();
      return;
    }
    _isShowing = true;
    _isLoaded  = false;
    Future.delayed(const Duration(seconds: 2), () {
      _isShowing = false;
      onUserEarnedReward(50, 'pieces_or');
      loadRewardedAd();
    });
  }

  void dispose() {
    _isLoaded  = false;
    _isShowing = false;
  }
}
