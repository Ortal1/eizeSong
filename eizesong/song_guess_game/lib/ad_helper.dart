import 'dart:io';

class AdHelper {
  // Test Ad Unit IDs from Google
  // Replace these with your real ad unit IDs when you're ready to publish

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test Banner Ad - Replace when ready
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test Banner Ad - Replace when ready
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial Ad
    } else if (Platform.isIOS) {
      // Use test ad for now until your real ad is approved by Google (24-48 hours)
      return 'ca-app-pub-3940256099942544/4411468910'; // Test iOS Interstitial Ad
      // Real ad (use after 24-48 hours): ca-app-pub-8926526298781831/9098138739
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test Rewarded Ad
    } else if (Platform.isIOS) {
      // Use test ad for now until your real ad is approved by Google (24-48 hours)
      return 'ca-app-pub-3940256099942544/1712485313'; // Test iOS Rewarded Ad
      // Real ad (use after 24-48 hours): ca-app-pub-8926526298781831/2399609265
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
