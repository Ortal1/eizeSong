import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify if a song exists in iTunes and get the exact title/artist
///
/// Usage:
/// dart test_song.dart "Artist Name" "Song Title"
///
/// Example:
/// dart test_song.dart "Ed Sheeran" "Shape of You"

Future<void> testSong(String artist, String title) async {
  print('🔍 Searching iTunes for: "$title" by $artist');
  print('─' * 60);

  final query = Uri.encodeQueryComponent('$artist $title');
  final uri = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=5&country=IL');

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      print('❌ Error: iTunes API returned status ${response.statusCode}');
      return;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();

    if (results.isEmpty) {
      print('❌ No results found!');
      print('💡 Tips:');
      print('   - Try different spelling variations');
      print('   - Check if the song is available in iTunes');
      print('   - Try searching with just the song title or artist');
      return;
    }

    print('✅ Found ${results.length} result(s):\n');

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final trackName = result['trackName'] ?? 'Unknown';
      final artistName = result['artistName'] ?? 'Unknown';
      final previewUrl = result['previewUrl'];
      final collectionName = result['collectionName'] ?? 'Unknown Album';

      print('Result ${i + 1}:');
      print('  📌 Track Name: "$trackName"');
      print('  🎤 Artist Name: "$artistName"');
      print('  💿 Album: "$collectionName"');
      print('  🎵 Preview Available: ${previewUrl != null ? "YES ✅" : "NO ❌"}');
      if (previewUrl != null) {
        print('  🔗 Preview URL: $previewUrl');
      }
      print('');
    }

    // Show recommended usage
    final bestMatch = results.first;
    print('─' * 60);
    print('📝 Recommended Song() constructor:');
    print('');
    print('Song(');
    print('  title: \'${bestMatch['trackName']}\',');
    print('  artist: \'${bestMatch['artistName']}\',');
    print('  language: Language.english,  // or Language.hebrew');
    print('),');
    print('');

    if (bestMatch['previewUrl'] == null) {
      print('⚠️  WARNING: This song has NO preview URL!');
      print('   The app won\'t be able to play a preview.');
      print('   Consider choosing a different song.');
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}

void main(List<String> args) async {
  // If no arguments provided, use default test values
  if (args.length != 2) {
    print('ℹ️  No arguments provided. Testing with default song...');
    print('');
    print('💡 To test a specific song from terminal, use:');
    print('   dart run test_song.dart "Artist Name" "Song Title"');
    print('');
    print('Examples:');
    print('  dart run test_song.dart "Omer Adam" "טקילה"');
    print('  dart run test_song.dart "נעמי שמר" "ירושלים של זהב"');
    print('  dart run test_song.dart "Adele" "Someone Like You"');
    print('');
    print('─' * 60);
    print('');

    // Default test - EDIT THESE VALUES to test your song:
    await testSong("Omer Adam", "טקילה");
    return;
  }

  final artist = args[0];
  final title = args[1];

  await testSong(artist, title);
}
