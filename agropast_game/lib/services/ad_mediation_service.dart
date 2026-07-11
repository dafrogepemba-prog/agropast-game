import 'package:flutter/foundation.dart';
import 'ad_mediation_mobile.dart'
    if (dart.library.html) 'ad_mediation_web.dart';

enum AdNetwork { admob, unityAds, appLovin }

class AdMediationService extends AdMediationServiceBase {
  static AdMediationService? _instance;
  factory AdMediationService() => _instance ??= AdMediationService._internal();
  AdMediationService._internal();
}

abstract class AdMediationServiceBase {
  static const Duration timeout = Duration(seconds: 7);
  static const int dailyCap = 8;

  bool get isLoaded;
  bool get isShowing;
  int get adsWatchedToday;
  bool get isCapReached => adsWatchedToday >= dailyCap;

  static Future<void> init() => AdMediationServiceBaseImpl.init();
  void loadAds({VoidCallback? onLoaded, VoidCallback? onAllFailed});
  void showRewardedAd({
    required Function(int amount, String type, AdNetwork network) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
    VoidCallback? onNoAdsAvailable,
  });
  void dispose();
  void updateAdsWatchedToday(int count);
}
