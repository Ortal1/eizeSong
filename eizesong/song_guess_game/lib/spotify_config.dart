/// Spotify API Configuration
/// Contains client credentials for Spotify Web API access
class SpotifyConfig {
  // Your Spotify App credentials from https://developer.spotify.com/dashboard
  static const String clientId = 'a57f9d632b174356bfde2a3cc5c4f5dc';
  static const String clientSecret = '417d8dc881ec4ca49fd371cf48652c45';

  // Not needed for Client Credentials flow (Web API preview access)
  static const String redirectUri = 'eizesong://spotify-login-callback';

  // Not needed for preview clips
  static const List<String> scopes = [];
}
