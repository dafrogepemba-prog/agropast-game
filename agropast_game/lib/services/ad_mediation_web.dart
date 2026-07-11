import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ad_mediation_service.dart';

class AdMediationServiceBaseImpl extends AdMediationServiceBase {
  AdMediationServiceBaseImpl() {
    _instance = this;
  }

  static AdMediationServiceBaseImpl? _instance;
  static AdMediationServiceBaseImpl get instance =>
      _instance ?? AdMediationServiceBaseImpl();

  bool _isShowing = false;
  int _adsWatchedToday = 0;

  @override
  bool get isLoaded => false; // No ads preloaded on web
  @override
  bool get isShowing => _isShowing;
  @override
  int get adsWatchedToday => _adsWatchedToday;

  static Future<void> init() async {
    // Web ads handled via AdSense H5 in index.html
    debugPrint('[AdMediation] Web init - no native ads');
  }

  @override
  void loadAds({VoidCallback? onLoaded, VoidCallback? onAllFailed}) {
    onAllFailed?.call(); // Fallback to H5 on web
  }

  @override
  void showRewardedAd({
    required Function(int amount, String type, AdNetwork network) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
    VoidCallback? onNoAdsAvailable,
  }) {
    onNoAdsAvailable?.call(); // Let web H5 handle it
  }

  @override
  void dispose() {}

  @override
  void updateAdsWatchedToday(int count) {
    _adsWatchedToday = count;
  }
}
