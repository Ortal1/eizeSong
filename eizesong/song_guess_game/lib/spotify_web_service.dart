import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spotify_config.dart';

/// Spotify Web API Service
/// Uses Spotify Web API to search tracks and get preview URLs
/// Works with both Free and Premium Spotify accounts
/// NO USER AUTHENTICATION REQUIRED - uses Client Credentials flow
class SpotifyWebService {
  static final SpotifyWebService _instance = SpotifyWebService._internal();
  factory SpotifyWebService() => _instance;
  SpotifyWebService._internal();

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Get access token using Client Credentials Flow
  /// This doesn't require user login - works for preview clips
  Future<String?> _getAccessToken() async {
    // Check if we have a valid cached token
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }
    }

    try {
      // Request token using Client Credentials
      final credentials = base64Encode(
        utf8.encode('${SpotifyConfig.clientId}:${SpotifyConfig.clientSecret}'),
      );

      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int; // seconds
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

        if (kDebugMode) {
          print('✅ [SPOTIFY] Got API access token');
        }

        return _accessToken;
      } else {
        if (kDebugMode) {
          print('❌ [SPOTIFY] Failed to get token: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SPOTIFY] Error getting token: $e');
      }
      return null;
    }
  }

  /// Search for a track and get preview URL
  /// Returns preview URL (30-second clip) or null if not found
  Future<String?> getTrackPreview(String title, String artist) async {
    final token = await _getAccessToken();
    if (token == null) {
      if (kDebugMode) {
        print('❌ [SPOTIFY] No access token available');
      }
      return null;
    }

    try {
      // Build search query
      final query = Uri.encodeComponent('track:$title artist:$artist');
      final url = 'https://api.spotify.com/v1/search?q=$query&type=track&limit=1&market=IL';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['tracks']['items'] as List;

        if (tracks.isNotEmpty) {
          final track = tracks[0];
          final previewUrl = track['preview_url'] as String?;

          if (kDebugMode) {
            if (previewUrl != null) {
              print('✅ [SPOTIFY] Found preview for "${track['name']}" by ${track['artists'][0]['name']}');
            } else {
              print('⚠️  [SPOTIFY] Track found but no preview available');
            }
          }

          return previewUrl;
        } else {
          if (kDebugMode) {
            print('❌ [SPOTIFY] No track found for "$title" by $artist');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('❌ [SPOTIFY] Search failed: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SPOTIFY] Error searching: $e');
      }
      return null;
    }
  }

  /// Get track info by Spotify URI
  /// Returns preview URL from the track URI
  Future<String?> getPreviewFromUri(String spotifyUri) async {
    // Extract track ID from URI (spotify:track:ABC123 -> ABC123)
    final trackId = spotifyUri.split(':').last;

    final token = await _getAccessToken();
    if (token == null) return null;

    try {
      final url = 'https://api.spotify.com/v1/tracks/$trackId?market=IL';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final previewUrl = data['preview_url'] as String?;

        if (kDebugMode) {
          if (previewUrl != null) {
            print('✅ [SPOTIFY] Got preview from URI');
          } else {
            print('⚠️  [SPOTIFY] No preview available for this track');
          }
        }

        return previewUrl;
      } else {
        if (kDebugMode) {
          print('❌ [SPOTIFY] Failed to get track: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SPOTIFY] Error getting track: $e');
      }
      return null;
    }
  }
}
