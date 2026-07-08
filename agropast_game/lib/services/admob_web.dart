import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================
// AdMob Web — simulation uniquement
// Les vraies pubs web passent par AdSense H5 (index.html)
// ============================================================

class AdMobService {
  static const String appId          = 'ca-app-pub-4115564366785475~5279911679';
  static const String rewardedAdUnit = 'ca-app-pub-4115564366785475/9740112422';

  bool _isLoaded  = false;
  bool _isShowing = false;

  bool get isLoaded  => false; // toujours false sur web → bouton WebBonus
  bool get isShowing => _isShowing;

  static Future<void> init() async {}

  void loadRewardedAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {}

  void showRewardedAd({
    required Function(int amount, String type) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    onAdFailedToShow?.call(); // sur web → fallback vers H5 Ads
  }

  void dispose() {}
}
