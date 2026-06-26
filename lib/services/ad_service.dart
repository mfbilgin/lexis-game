import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firestore_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  final userStatsAsync = ref.watch(userStatsProvider);
  final hasRemovedAds = userStatsAsync.value?.hasRemovedAds ?? false;
  
  final service = AdService(hasRemovedAds: hasRemovedAds);
  return service;
});

class AdService {
  final bool hasRemovedAds;
  
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  
  bool _isInterstitialAdLoading = false;
  bool _isRewardedAdLoading = false;

  AdService({required this.hasRemovedAds}) {
    if (!hasRemovedAds) {
      loadInterstitialAd();
    }
    loadRewardedAd(); // Rewarded ads are always available
  }

  // --- Test Ad Unit IDs ---
  String get interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  String get rewardedAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  // --- Interstitial Ad ---
  void loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;
    
    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onAdDismissed}) {
    if (hasRemovedAds) {
      onAdDismissed?.call();
      return;
    }

    if (_interstitialAd == null) {
      debugPrint('Warning: attempt to show interstitial before loaded.');
      onAdDismissed?.call();
      loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }

  // --- Rewarded Ad ---
  void loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onUserEarnedReward, VoidCallback? onAdDismissed}) {
    if (_rewardedAd == null) {
      debugPrint('Warning: attempt to show rewarded before loaded.');
      // Since it's not loaded, we can't give reward. We might call dismissed.
      onAdDismissed?.call();
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed?.call();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
      onUserEarnedReward();
    });
  }
}
