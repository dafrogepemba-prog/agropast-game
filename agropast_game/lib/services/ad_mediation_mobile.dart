import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'ad_mediation_service.dart';

class AdMediationServiceBaseImpl extends AdMediationServiceBase {
  AdMediationServiceBaseImpl() {
    _instance = this;
  }

  static AdMediationServiceBaseImpl? _instance;
  static AdMediationServiceBaseImpl get instance =>
      _instance ?? AdMediationServiceBaseImpl();

  // AdMob
  static const String _admobAppId = 'ca-app-pub-4115564366785475~5279911679';
  static const String _admobRewardedAdUnit = 'ca-app-pub-4115564366785475/9740112422';
  RewardedAd? _admobRewardedAd;
  bool _admobLoaded = false;

  // Unity Ads
  static const String _unityGameIdAndroid = '5617423'; // Replace with your actual Unity Game ID
  static const String _unityRewardedPlacementId = 'rewardedVideo';
  bool _unityLoaded = false;
  bool _unityInitialized = false;

  bool _isShowing = false;
  int _adsWatchedToday = 0;

  @override
  bool get isLoaded => _admobLoaded || _unityLoaded;
  @override
  bool get isShowing => _isShowing;
  @override
  int get adsWatchedToday => _adsWatchedToday;

  static Future<void> init() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    debugPrint('[AdMediation] AdMob SDK initialisé — $_admobAppId');
    await UnityAds.init(
      gameId: _unityGameIdAndroid,
      testMode: true, // Set to false in production
      onComplete: () {
        instance._unityInitialized = true;
        debugPrint('[AdMediation] Unity Ads initialisé');
        instance._loadUnityAd();
      },
      onFailed: (error, message) {
        debugPrint('[AdMediation] Unity Ads init failed: $error $message');
      },
    );
  }

  @override
  void loadAds({VoidCallback? onLoaded, VoidCallback? onAllFailed}) {
    if (kIsWeb) return;

    bool anyLoaded = false;

    // Load AdMob first
    _loadAdMobAd(
      onLoaded: () {
        anyLoaded = true;
        onLoaded?.call();
      },
      onFailed: () {
        // Fallback to Unity Ads
        _loadUnityAd(
          onLoaded: () {
            anyLoaded = true;
            onLoaded?.call();
          },
          onFailed: () {
            if (!anyLoaded) onAllFailed?.call();
          },
        );
      },
    );
  }

  void _loadAdMobAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    bool callbackCalled = false;
    
    RewardedAd.load(
      adUnitId: _admobRewardedAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (callbackCalled) return;
          callbackCalled = true;
          _admobRewardedAd = ad;
          _admobLoaded = true;
          debugPrint('[AdMediation] AdMob loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          if (callbackCalled) return;
          callbackCalled = true;
          _admobRewardedAd = null;
          _admobLoaded = false;
          debugPrint('[AdMediation] AdMob load failed: ${error.message}');
          onFailed?.call();
        },
      ),
    );

    // Timeout: if no callback after 7s, call onFailed
    Future.delayed(AdMediationServiceBase.timeout, () {
      if (!callbackCalled) {
        callbackCalled = true;
        _admobRewardedAd = null;
        _admobLoaded = false;
        debugPrint('[AdMediation] AdMob load timed out');
        onFailed?.call();
      }
    });
  }

  void _loadUnityAd({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    if (!_unityInitialized) {
      onFailed?.call();
      return;
    }

    bool callbackCalled = false;

    UnityAds.load(
      placementId: _unityRewardedPlacementId,
      onComplete: (placementId) {
        if (callbackCalled) return;
        callbackCalled = true;
        _unityLoaded = true;
        debugPrint('[AdMediation] Unity Ads loaded');
        onLoaded?.call();
      },
      onFailed: (placementId, error, message) {
        if (callbackCalled) return;
        callbackCalled = true;
        _unityLoaded = false;
        debugPrint('[AdMediation] Unity Ads load failed: $error $message');
        onFailed?.call();
      },
    );

    // Timeout: if no callback after 7s, call onFailed
    Future.delayed(AdMediationServiceBase.timeout, () {
      if (!callbackCalled) {
        callbackCalled = true;
        _unityLoaded = false;
        debugPrint('[AdMediation] Unity Ads load timed out');
        onFailed?.call();
      }
    });
  }

  @override
  void showRewardedAd({
    required Function(int amount, String type, AdNetwork network) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
    VoidCallback? onNoAdsAvailable,
  }) {
    if (kIsWeb || _isShowing) {
      onAdFailedToShow?.call();
      return;
    }

    _isShowing = true;

    // Try AdMob first
    if (_admobLoaded && _admobRewardedAd != null) {
      _showAdMobAd(
        onUserEarnedReward: onUserEarnedReward,
        onAdDismissedWithoutReward: onAdDismissedWithoutReward,
        onAdFailedToShow: () {
          // Fallback to Unity Ads
          _showUnityAd(
            onUserEarnedReward: onUserEarnedReward,
            onAdDismissedWithoutReward: onAdDismissedWithoutReward,
            onAdFailedToShow: () {
              _isShowing = false;
              onNoAdsAvailable?.call();
            },
          );
        },
      );
    } else if (_unityLoaded) {
      _showUnityAd(
        onUserEarnedReward: onUserEarnedReward,
        onAdDismissedWithoutReward: onAdDismissedWithoutReward,
        onAdFailedToShow: () {
          _isShowing = false;
          onNoAdsAvailable?.call();
        },
      );
    } else {
      _isShowing = false;
      onNoAdsAvailable?.call();
    }
  }

  void _showAdMobAd({
    required Function(int amount, String type, AdNetwork network) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    bool rewarded = false;
    _admobLoaded = false;

    _admobRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _admobRewardedAd = null;
        _isShowing = false;
        if (!rewarded) onAdDismissedWithoutReward?.call();
        _loadAdMobAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _admobRewardedAd = null;
        _isShowing = false;
        debugPrint('[AdMediation] AdMob show failed: ${error.message}');
        onAdFailedToShow?.call();
        _loadAdMobAd();
      },
    );

    _admobRewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
      rewarded = true;
      _adsWatchedToday++;
      onUserEarnedReward(reward.amount.toInt(), reward.type, AdNetwork.admob);
      debugPrint('[AdMediation] AdMob reward earned');
    },
    );
  }

  void _showUnityAd({
    required Function(int amount, String type, AdNetwork network) onUserEarnedReward,
    VoidCallback? onAdDismissedWithoutReward,
    VoidCallback? onAdFailedToShow,
  }) {
    bool rewarded = false;
    _unityLoaded = false;

    UnityAds.showVideoAd(
      placementId: _unityRewardedPlacementId,
      onStart: (placementId) => debugPrint('[AdMediation] Unity ad started'),
      onClick: (placementId) => debugPrint('[AdMediation] Unity ad clicked'),
      onComplete: (placementId) {
        rewarded = true;
        _adsWatchedToday++;
        onUserEarnedReward(50, 'coins', AdNetwork.unityAds);
        debugPrint('[AdMediation] Unity reward earned');
      },
      onSkipped: (placementId) => debugPrint('[AdMediation] Unity ad skipped'),
      onFailed: (placementId, error, message) {
        debugPrint('[AdMediation] Unity ad failed: $error $message');
        _isShowing = false;
        onAdFailedToShow?.call();
        _loadUnityAd();
      },
    );
  }

  @override
  void dispose() {
    _admobRewardedAd?.dispose();
    _admobRewardedAd = null;
    _admobLoaded = false;
    _unityLoaded = false;
    _isShowing = false;
  }

  @override
  void updateAdsWatchedToday(int count) {
    _adsWatchedToday = count;
  }
}
