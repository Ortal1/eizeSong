import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsHelper {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // App lifecycle events
  static Future<void> logAppStart() async {
    await _analytics.logEvent(
      name: 'app_start',
      parameters: {},
    );
  }

  static Future<void> logLevelSelected(int levelIndex, String levelTitle) async {
    await _analytics.logEvent(
      name: 'level_selected',
      parameters: {
        'level_index': levelIndex,
        'level_title': levelTitle,
      },
    );
  }

  // Game events
  static Future<void> logSongPlayed({
    required int levelIndex,
    required int songIndex,
    required int exposureSeconds,
  }) async {
    await _analytics.logEvent(
      name: 'song_played',
      parameters: {
        'level_index': levelIndex,
        'song_index': songIndex,
        'exposure_seconds': exposureSeconds,
      },
    );
  }

  static Future<void> logSongSolved({
    required int levelIndex,
    required int songIndex,
    required int points,
    required int attempts,
    required int hintsUsed,
    required int timeSeconds,
  }) async {
    await _analytics.logEvent(
      name: 'song_solved',
      parameters: {
        'level_index': levelIndex,
        'song_index': songIndex,
        'points': points,
        'attempts': attempts,
        'hints_used': hintsUsed,
        'time_seconds': timeSeconds,
      },
    );
  }

  static Future<void> logSongSkipped({
    required int levelIndex,
    required int songIndex,
    required int attempts,
  }) async {
    await _analytics.logEvent(
      name: 'song_skipped',
      parameters: {
        'level_index': levelIndex,
        'song_index': songIndex,
        'attempts': attempts,
      },
    );
  }

  static Future<void> logLevelCompleted({
    required int levelIndex,
    required String levelTitle,
    required int totalPoints,
  }) async {
    await _analytics.logEvent(
      name: 'level_completed',
      parameters: {
        'level_index': levelIndex,
        'level_title': levelTitle,
        'total_points': totalPoints,
      },
    );
  }

  // Hint events
  static Future<void> logHintUsed({
    required int levelIndex,
    required int songIndex,
    required String hintType, // 'points' or 'ad'
    required int hintNumber, // 1, 2, or 3
    required int? cost, // null if ad
  }) async {
    await _analytics.logEvent(
      name: 'hint_used',
      parameters: {
        'level_index': levelIndex,
        'song_index': songIndex,
        'hint_type': hintType,
        'hint_number': hintNumber,
        'cost': cost ?? 0,
      },
    );
  }

  // Ad events
  static Future<void> logAdShown({
    required String adType, // 'interstitial' or 'rewarded'
    required String trigger, // 'level_complete', 'hint_request', etc.
  }) async {
    await _analytics.logEvent(
      name: 'ad_shown',
      parameters: {
        'ad_type': adType,
        'trigger': trigger,
      },
    );
  }

  static Future<void> logAdFailedToShow({
    required String adType,
    required String error,
  }) async {
    await _analytics.logEvent(
      name: 'ad_failed',
      parameters: {
        'ad_type': adType,
        'error': error,
      },
    );
  }

  // User progression
  static Future<void> logScoreChanged({
    required int newScore,
    required int delta,
  }) async {
    await _analytics.logEvent(
      name: 'score_changed',
      parameters: {
        'new_score': newScore,
        'delta': delta,
      },
    );
  }

  // Set user properties for segmentation
  static Future<void> setUserProperties({
    int? currentLevel,
    int? totalScore,
  }) async {
    if (currentLevel != null) {
      await _analytics.setUserProperty(
        name: 'current_level',
        value: currentLevel.toString(),
      );
    }
    if (totalScore != null) {
      await _analytics.setUserProperty(
        name: 'total_score',
        value: totalScore.toString(),
      );
    }
  }
}
