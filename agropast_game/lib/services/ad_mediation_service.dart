import 'package:flutter/foundation.dart';
import 'ad_mediation_mobile.dart'
    if (dart.library.html) 'ad_mediation_web.dart';

enum AdNetwork { admob, unityAds, appLovin }

class AdMediationService extends AdMediationServiceBase {
  static AdMediationService? _instance;
  factory AdMediationService() => _instance ??= AdMediationService._internal();
  AdMediationService._internal();

  static final AdMediationServiceBase _impl = kIsWeb
      ? AdMediationServiceBaseImpl.instance
      : AdMediationServiceBaseImpl.instance;

  @override
  bool get isLoaded => _impl.isLoaded;

  @override
  bool get isShowing => _impl.isShowing;

  @override
  int get adsWatchedToday => _impl.adsWatchedToday;

  @override
  void loadAds({VoidCallback? onLoaded, VoidCallback? onAllFailed}) {
    _impl.loadAds(onLoaded: onLoaded, onAllFailed: onAllFailed);
  }

  @override
  void showRewardedAd({
    required Function(int amount, String type, AdNetwork network) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
    VoidCallback? onNoAdsAvailable,
  }) {
    _impl.showRewardedAd(
      onUserEarnedReward: onUserEarnedReward,
      onAdDismissedWithoutReward: onAdDismissedWithoutReward,
      onAdFailedToShow: onAdFailedToShow,
      onNoAdsAvailable: onNoAdsAvailable,
    );
  }

  @override
  void dispose() {
    _impl.dispose();
  }

  @override
  void updateAdsWatchedToday(int count) {
    _impl.updateAdsWatchedToday(count);
  }
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
