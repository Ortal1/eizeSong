import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test multiple songs at once to see which ones work in iTunes
/// Add your songs to the list below and run this script

class SongToTest {
  final String title;
  final String artist;

  SongToTest(this.title, this.artist);
}

Future<Map<String, dynamic>?> testSong(String artist, String title) async {
  final query = Uri.encodeQueryComponent('$artist $title');
  final uri = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=5&country=IL');

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();

    if (results.isEmpty) {
      return null;
    }

    // Return the best match
    return results.first;
  } catch (_) {
    return null;
  }
}

void main() async {
  // ═══════════════════════════════════════════════════════════════
  // ADD YOUR SONGS HERE TO TEST THEM
  // ═══════════════════════════════════════════════════════════════
  final songsToTest = [
    // Popular Hebrew songs
    SongToTest('טקילה', 'Omer Adam'),
    SongToTest('תודה', 'Idan Raichel'),
    SongToTest('בואי', 'Static and Ben El Tavori'),
    SongToTest('ממעמקים', 'Idan Raichel'),
    SongToTest('גבר הולך לאיבוד', 'Shlomo Artzi'),
    SongToTest('מלאך', 'Static and Ben El Tavori'),
    SongToTest('את לא לבד', 'Noa Kirel'),
    SongToTest('פרח בגני', 'Amir Dadon'),
    SongToTest('צאי לאור', 'Omer Adam'),
    SongToTest('תן לי', 'Omer Adam'),

    // Add more songs here to test:
    // SongToTest('שם השיר', 'שם האמן'),
  ];

  print('╔════════════════════════════════════════════════════════════╗');
  print('║         Testing ${songsToTest.length} Songs in iTunes                       ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');

  final workingSongs = <Map<String, dynamic>>[];
  final failedSongs = <SongToTest>[];

  for (int i = 0; i < songsToTest.length; i++) {
    final song = songsToTest[i];
    print('[$i/${songsToTest.length}] Testing: "${song.title}" by ${song.artist}...');

    final result = await testSong(song.artist, song.title);

    if (result != null && result['previewUrl'] != null) {
      print('  ✅ WORKS - Found with preview');
      workingSongs.add({
        'original': song,
        'itunes': result,
      });
    } else if (result != null) {
      print('  ⚠️  FOUND but NO preview URL - won\'t work in app');
      failedSongs.add(song);
    } else {
      print('  ❌ NOT FOUND in iTunes');
      failedSongs.add(song);
    }
    print('');

    // Small delay to be nice to iTunes API
    await Future.delayed(const Duration(milliseconds: 300));
  }

  print('');
  print('═' * 60);
  print('SUMMARY');
  print('═' * 60);
  print('✅ Working songs: ${workingSongs.length}');
  print('❌ Failed songs: ${failedSongs.length}');
  print('');

  if (workingSongs.isNotEmpty) {
    print('─' * 60);
    print('READY TO ADD TO YOUR GAME:');
    print('─' * 60);
    print('');

    for (final item in workingSongs) {
      final itunes = item['itunes'] as Map<String, dynamic>;
      final trackName = itunes['trackName'];
      final artistName = itunes['artistName'];

      print('Song(');
      print('  title: \'$trackName\',');
      print('  artist: \'$artistName\',');
      print('  language: Language.hebrew,');
      print('),');
      print('');
    }
  }

  if (failedSongs.isNotEmpty) {
    print('─' * 60);
    print('FAILED SONGS (won\'t work):');
    print('─' * 60);
    for (final song in failedSongs) {
      print('❌ "${song.title}" by ${song.artist}');
    }
    print('');
    print('💡 Tip: Try different spelling or romanized versions');
  }

  print('');
  print('Done! Copy the working songs above into your main.dart');
}
