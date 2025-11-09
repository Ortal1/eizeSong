import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_helper.dart';
import 'analytics_helper.dart';
import 'firebase_options.dart';

/* =========================
   PERFORMANCE HELPERS
   ========================= */
class PreviewCache {
  static final Map<String, String?> _cache = {};

  static String _key(String title, String artist) => '${title.trim()}|${artist.trim()}';

  static String? get(String title, String artist) => _cache[_key(title, artist)];

  static void set(String title, String artist, String? url) {
    _cache[_key(title, artist)] = url;
  }
}

class AudioFx {
  static final AudioPlayer player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> warmNetwork(String url) async {
    try {
      await player.setSourceUrl(url);
      await player.setVolume(0);
      await player.resume();
      await Future.delayed(const Duration(milliseconds: 150));
      await player.pause();
      await player.setVolume(1);
    } catch (_) {}
  }
}

/* =========================
   USER DATA STORAGE
   ========================= */
class UserDataHelper {
  static const String _keyUsername = 'username';
  static const String _keyScore = 'totalScore';
  static const String _keySolvedSongs = 'solvedSongs';

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  static Future<int> getScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyScore) ?? 0;
  }

  static Future<void> saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyScore, score);
  }

  static Future<Map<String, bool>> getSolvedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keySolvedSongs);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      return decoded.map((key, value) => MapEntry(key, value as bool));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveSolvedSongs(Map<String, bool> solvedSongs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(solvedSongs);
    await prefs.setString(_keySolvedSongs, jsonString);
  }

  static String getSongKey(int levelIndex, int songIndex) {
    return 'L${levelIndex}_S$songIndex';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  await AnalyticsHelper.logAppStart();
  runApp(const SongGuessApp());
}

/* =========================
   ROOT APP + GLOBAL SCORE
   ========================= */
class SongGuessApp extends StatefulWidget {
  const SongGuessApp({super.key});

  @override
  State<SongGuessApp> createState() => _SongGuessAppState();
}

class _SongGuessAppState extends State<SongGuessApp> {
  final ValueNotifier<int> _score = ValueNotifier<int>(0);

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ניחוש שירים',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0D), // Apple dark-ish
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF), // iOS accent blue
          secondary: Color(0xFF64D2FF),
          surface: Color(0xFF1C1C1E),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 2),
          ),
          hintStyle: const TextStyle(color: Color(0x99FFFFFF)),
        ),
      ),
      home: StartScreen(score: _score),
    );
  }
}

/* =========================
   REUSABLE UI PRIMITIVES
   ========================= */
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x33FFFFFF),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: child,
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final ValueListenable<int> score;
  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: score,
      builder: (context, value, _) {
        return Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFF0A84FF), Color(0xFF64D2FF)]),
            boxShadow: [BoxShadow(color: const Color(0xFF0A84FF).withOpacity(0.4), blurRadius: 14)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, color: Colors.black, size: 18),
            const SizedBox(width: 6),
            Text('$value',
                style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          ]),
        );
      },
    );
  }
}

/* =========================
   MODELS
   ========================= */
enum Language { hebrew, english }

class Song {
  final String title;
  final String artist;
  final Language language;
  String? previewUrl;
  bool isSolved;
  final int? year;
  final String? theme;
  final bool? isBand;

  Song({
    required this.title,
    required this.artist,
    required this.language,
    this.previewUrl,
    this.isSolved = false,
    this.year,
    this.theme,
    this.isBand,
  });
}

class Level {
  final int index;
  final String title;
  final List<Song> songs;
  bool isUnlocked;

  Level({
    required this.index,
    required this.title,
    required this.songs,
    this.isUnlocked = true,
  });

  int get solvedCount => songs.where((s) => s.isSolved).length;
}

/* =========================
   DATA + HELPERS
   ========================= */
String normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\p{P}+', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool isTitleMatch(String userInput, String expected) {
  final a = normalize(userInput);
  final b = normalize(expected);
  if (a == b) return true;
  if (a.length >= (b.length * 0.7) && b.contains(a)) {
    return true;
  }
  return false;
}

Future<String?> fetchItunesPreview(String title, String artist) async {
  try {
    final q = Uri.encodeQueryComponent('$artist $title');
    final uri = Uri.parse('https://itunes.apple.com/search?term=$q&entity=song&limit=5&country=IL');
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    if (results.isEmpty) return null;

    final tNorm = normalize(title);
    final aNorm = normalize(artist);

    for (final r in results) {
      final tn = normalize(r['trackName']?.toString() ?? '');
      final an = normalize(r['artistName']?.toString() ?? '');
      if (tn.isNotEmpty &&
          an.isNotEmpty &&
          (tn.contains(tNorm) || tNorm.contains(tn)) &&
          (an.contains(aNorm) || aNorm.contains(an)) &&
          r['previewUrl'] != null) {
        return r['previewUrl'] as String;
      }
    }
    for (final r in results) {
      if (r['previewUrl'] != null) return r['previewUrl'] as String;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/* =========================
   START SCREEN (MERGED) – Apple Dark Style
   ========================= */
class StartScreen extends StatefulWidget {
  final ValueNotifier<int> score;
  const StartScreen({super.key, required this.score});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  late final Animation<double> _pulse = Tween<double>(begin: 0.98, end: 1.04).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final username = await UserDataHelper.getUsername().timeout(const Duration(seconds: 2));
      final score = await UserDataHelper.getScore().timeout(const Duration(seconds: 1));
      if (username != null && username.isNotEmpty) {
        _usernameController.text = username;
      }
      widget.score.value = score;
    } catch (_) {}
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('נא להזין שם משתמש')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await UserDataHelper.saveUsername(username).timeout(const Duration(seconds: 3));
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LevelSelectionPage(score: widget.score)));
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LevelSelectionPage(score: widget.score)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('ניחוש שירים', textAlign: TextAlign.center),
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: Stack(
        children: [
          const _AppleDarkBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _pulse,
                        child: const Icon(Icons.music_note_rounded, size: 96, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      const Text('ברוכה הבאה ואם שבה אז שווה',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _usernameController,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'הזיני שם משתמש',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _start(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _start,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(_isLoading ? 'טוען…' : 'התחילי', textAlign: TextAlign.center),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            foregroundColor: Colors.white,
                            elevation: 20,
                            shadowColor: const Color(0xFF0A84FF).withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('ההתקדמות שלך תישמר אוטומטית',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleDarkBackground extends StatelessWidget {
  const _AppleDarkBackground();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 18),
      curve: Curves.linear,
      builder: (context, value, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + value, -1),
              end: Alignment(1, 1 - value),
              colors: const [
                Color(0xFF0B0B0D),
                Color(0xFF141416),
                Color(0xFF1C1C1E),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* =========================
   LEVEL SELECTION – (kept, minor style)
   ========================= */
class LevelSelectionPage extends StatefulWidget {
  final ValueNotifier<int> score;
  const LevelSelectionPage({super.key, required this.score});

  @override
  State<LevelSelectionPage> createState() => _LevelSelectionPageState();
}

class _LevelSelectionPageState extends State<LevelSelectionPage> {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  late final List<Level> levels = [
    Level(
      index: 1,
      title: 'שלב לאה - שירי קאלט משנות ה-70 וה-80',
      songs: [
        Song(title: 'Bohemian Rhapsody', artist: 'Queen', language: Language.english, year: 1975, theme: 'חיים ומוות', isBand: true),
        Song(title: 'Hotel California', artist: 'Eagles', language: Language.english, year: 1976, theme: 'מלון מסתורי', isBand: true),
        Song(title: 'Stairway to Heaven', artist: 'Led Zeppelin', language: Language.english, year: 1971, theme: 'רוחניות ושאיפה', isBand: true),
        Song(title: 'Imagine', artist: 'John Lennon', language: Language.english, year: 1971, theme: 'שלום עולמי', isBand: false),
        Song(title: 'Don\'t Stop Believin\'', artist: 'Journey', language: Language.english, year: 1981, theme: 'תקווה וחלומות', isBand: true),
        Song(title: 'Sweet Child O\' Mine', artist: 'Guns N\' Roses', language: Language.english, year: 1987, theme: 'אהבה', isBand: true),
        Song(title: 'Billie Jean', artist: 'Michael Jackson', language: Language.english, year: 1982, theme: 'אהבה ובגידה', isBand: false),
        Song(title: 'Stayin\' Alive', artist: 'Bee Gees', language: Language.english, year: 1977, theme: 'שרידות והישארות', isBand: true),
        Song(title: 'I Will Survive', artist: 'Gloria Gaynor', language: Language.english, year: 1978, theme: 'כוח והתגברות', isBand: false),
        Song(title: 'Africa', artist: 'Toto', language: Language.english, year: 1982, theme: 'געגועים ואהבה', isBand: true),
        Song(title: 'Livin\' on a Prayer', artist: 'Bon Jovi', language: Language.english, year: 1986, theme: 'אהבה ומאבק', isBand: true),
        Song(title: 'Sweet Dreams', artist: 'Eurythmics', language: Language.english, year: 1983, theme: 'שאיפות ורצונות', isBand: true),
        Song(title: 'Take On Me', artist: 'a-ha', language: Language.english, year: 1985, theme: 'אהבה רומנטית', isBand: true),
        Song(title: 'Every Breath You Take', artist: 'The Police', language: Language.english, year: 1983, theme: 'אובססיה ואהבה', isBand: true),
        Song(title: 'With or Without You', artist: 'U2', language: Language.english, year: 1987, theme: 'אהבה מסובכת', isBand: true),
        Song(title: 'Careless Whisper', artist: 'George Michael', language: Language.english, year: 1984, theme: 'חרטה ואובדן', isBand: false),
        Song(title: 'Beat It', artist: 'Michael Jackson', language: Language.english, year: 1982, theme: 'אלימות והימנעות', isBand: false),
        Song(title: 'Purple Rain', artist: 'Prince', language: Language.english, year: 1984, theme: 'אהבה ואובדן', isBand: false),
        Song(title: 'Eye of the Tiger', artist: 'Survivor', language: Language.english, year: 1982, theme: 'נחישות וכוח', isBand: true),
        Song(title: 'Girls Just Want to Have Fun', artist: 'Cyndi Lauper', language: Language.english, year: 1983, theme: 'חופש ושמחה', isBand: false),
      ],
      isUnlocked: true,
    ),
    Level(
      index: 2,
      title: 'שלב 2 - פופ ישראלי',
      songs: [
        Song(title: 'נובמבר', artist: 'מירי מסיקה', language: Language.hebrew, year: 2003, theme: 'זיכרונות ואהבה', isBand: false),
        Song(title: 'עד הקצה', artist: 'דנה ברגר', language: Language.hebrew, year: 2006, theme: 'תשוקה ואהבה', isBand: false),
        Song(title: 'השקט שנשאר', artist: 'שירי מימון', language: Language.hebrew, year: 2012, theme: 'אובדן וזיכרון', isBand: false),
        Song(title: 'הלב', artist: 'מאיה בוסקילה', language: Language.hebrew, year: 2010, theme: 'אהבה', isBand: false),
        Song(title: 'מלכת הדור', artist: 'עומר אדם', language: Language.hebrew, year: 2016, theme: 'קסם ואהבה', isBand: false),
        Song(title: 'כמה עוד אפשר', artist: 'הראל סקעת', language: Language.hebrew, year: 2009, theme: 'תסכול וכעס', isBand: false),
        Song(title:'מבול', artist: 'קרן פלס', language: Language.hebrew, year: 2009, theme: 'רגשות עזים', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 3,
      title: 'שלב 3 - רוק ומזרחי',
      songs: [
        Song(title: 'טקילה', artist: 'עומר אדם', language: Language.hebrew, year: 2019, theme: 'מסיבה ואהבה', isBand: false),
        Song(title: 'חולות של תל אביב', artist: 'אושר כהן', language: Language.hebrew, year: 2015, theme: 'עיר הולדת', isBand: false),
        Song(title: 'זמן שזז', artist: 'עידן עמדי', language: Language.hebrew, year: 2014, theme: 'זמן ושינוי', isBand: false),
        Song(title: 'רצים באדום', artist: 'תובל שפיר', language: Language.hebrew, year: 2016, theme: 'אהבה וסכנה', isBand: false),
        Song(title: 'מתי נתנשק', artist: 'ישיר', language: Language.hebrew, year: 2021, theme: 'געגועים', isBand: true),
        Song(title: 'דבר אליי', artist: 'אייל גולן', language: Language.hebrew, year: 2006, theme: 'תקשורת באהבה', isBand: false),
        Song(title: 'ים של דמעות', artist: 'זהבה בן', language: Language.hebrew, year: 1988, theme: 'כאב ודמעות', isBand: false),
        Song(title: 'אינטואיציה', artist: 'גדי צלניקר', language: Language.hebrew, year: 2018, theme: 'תחושת בטן', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 4,
      title: 'שלב 4 - היטים עולמיים עדכניים',
      songs: [
        Song(title: 'Not Like Us', artist: 'Kendrick Lamar', language: Language.english, year: 2024, theme: 'מחלוקת והשוואה', isBand: false),
        Song(title: 'Espresso', artist: 'Sabrina Carpenter', language: Language.english, year: 2024, theme: 'קפה ורומנטיקה', isBand: false),
        Song(title: 'Beautiful Things', artist: 'Benson Boone', language: Language.english, year: 2024, theme: 'פחד לאבד', isBand: false),
        Song(title: 'A Bar Song (Tipsy)', artist: 'Shaboozey', language: Language.english, year: 2024, theme: 'בר ומסיבה', isBand: false),
        Song(title: 'Houdini', artist: 'Dua Lipa', language: Language.english, year: 2023, theme: 'היעלמות מאהבה', isBand: false),
        Song(title: 'As It Was', artist: 'Harry Styles', language: Language.english, year: 2022, theme: 'שינוי ונוסטלגיה', isBand: false),
        Song(title: 'Flowers', artist: 'Miley Cyrus', language: Language.english, year: 2023, theme: 'אהבה עצמית', isBand: false),
        Song(title: 'Anti-Hero', artist: 'Taylor Swift', language: Language.english, year: 2022, theme: 'ביקורת עצמית', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 5,
      title: 'שלב 5 - שירי זמר (ישראליות נצחיות)',
      songs: [
        Song(title: 'לו יהי', artist: 'נעמי שמר', language: Language.hebrew, year: 1973, theme: 'שלום ותקווה', isBand: false),
        Song(title: 'אוף גוזל', artist: 'אריק איינשטיין', language: Language.hebrew, year: 1982, theme: 'אהבה', isBand: false),
        Song(title: 'פתאום', artist: 'יהודית רביץ', language: Language.hebrew, year: 1978, theme: 'פגישה באקראי', isBand: false),
        Song(title: 'שיר לשלום', artist: 'מירי אלוני', language: Language.hebrew, year: 1969, theme: 'שלום', isBand: false),
        Song(title: 'הבלדה על חדוה ושלומיק', artist: 'שלום חנוך', language: Language.hebrew, year: 1969, theme: 'סיפור אהבה טראגי', isBand: false),
        Song(title: 'רחוב האגס 1', artist: 'להקת כוורת', language: Language.hebrew, year: 1973, theme: 'ילדות ונוסטלגיה', isBand: true),
        Song(title: 'אני ואתה', artist: 'אריק איינשטיין', language: Language.hebrew, year: 1974, theme: 'שינוי העולם ביחד', isBand: false),
        Song(title: 'יש כוכבים', artist: 'נורית גלרון', language: Language.hebrew, year: 1977, theme: 'כוכבים וחלומות', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 6,
      title: 'שלב 6 - דאנס ואלקטרוני',
      songs: [
        Song(title: 'Wake Me Up', artist: 'Avicii', language: Language.english, year: 2013, theme: 'התבגרות ומציאת דרך', isBand: false),
        Song(title: 'One Kiss', artist: 'Calvin Harris', language: Language.english, year: 2018, theme: 'נשיקה אחת', isBand: false),
        Song(title: 'Head & Heart', artist: 'Joel Corry', language: Language.english, year: 2020, theme: 'קונפליקט פנימי', isBand: false),
        Song(title: 'I\'m Good (Blue)', artist: 'David Guetta', language: Language.english, year: 2022, theme: 'הרגשה טובה', isBand: false),
        Song(title: 'Closer', artist: 'The Chainsmokers', language: Language.english, year: 2016, theme: 'קרבה ונוסטלגיה', isBand: true),
        Song(title: 'Despacito', artist: 'Luis Fonsi', language: Language.english, year: 2017, theme: 'רומנטיקה איטית', isBand: false),
        Song(title: 'Pepas', artist: 'Farruko', language: Language.english, year: 2021, theme: 'מסיבה ואנרגיה', isBand: false),
        Song(title: 'Titanium', artist: 'David Guetta ft Sia', language: Language.english, year: 2011, theme: 'כוח ועמידות', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 7,
      title: 'שלב 7 - היפ הופ ו-R&B',
      songs: [
        Song(title: 'Lose Yourself', artist: 'Eminem', language: Language.english, year: 2002, theme: 'הזדמנות אחת', isBand: false),
        Song(title: 'In Da Club', artist: '50 Cent', language: Language.english, year: 2003, theme: 'מסיבת יומולדת', isBand: false),
        Song(title: 'Hotline Bling', artist: 'Drake', language: Language.english, year: 2015, theme: 'שיחות טלפון באהבה', isBand: false),
        Song(title: 'HUMBLE.', artist: 'Kendrick Lamar', language: Language.english, year: 2017, theme: 'ענווה ואמת', isBand: false),
        Song(title: 'Crazy in Love', artist: 'Beyoncé', language: Language.english, year: 2003, theme: 'אהבה משוגעת', isBand: false),
        Song(title: 'Umbrella', artist: 'Rihanna', language: Language.english, year: 2007, theme: 'הגנה ותמיכה', isBand: false),
        Song(title: 'Gold Digger', artist: 'Kanye West', language: Language.english, year: 2005, theme: 'אהבה למען כסף', isBand: false),
        Song(title: 'See You Again', artist: 'Wiz Khalifa', language: Language.english, year: 2015, theme: 'זיכרון וחברות', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 8,
      title: 'שלב 8 - שנות ה-80 וה-90',
      songs: [
        Song(title: 'Take On Me', artist: 'a-ha', language: Language.english, year: 1985, theme: 'אהבה רומנטית', isBand: true),
        Song(title: 'Livin\' on a Prayer', artist: 'Bon Jovi', language: Language.english, year: 1986, theme: 'אהבה ומאבק', isBand: true),
        Song(title: 'Sweet Dreams', artist: 'Eurythmics', language: Language.english, year: 1983, theme: 'שאיפות ורצונות', isBand: true),
        Song(title: 'Every Breath You Take', artist: 'The Police', language: Language.english, year: 1983, theme: 'אובססיה ואהבה', isBand: true),
        Song(title: 'Wonderwall', artist: 'Oasis', language: Language.english, year: 1995, theme: 'אהבה והצלה', isBand: true),
        Song(title: 'Baby One More Time', artist: 'Britney Spears', language: Language.english, year: 1998, theme: 'געגועים באהבה', isBand: false),
        Song(title: 'Wannabe', artist: 'Spice Girls', language: Language.english, year: 1996, theme: 'חברות ואהבה', isBand: true),
        Song(title: 'Vogue', artist: 'Madonna', language: Language.english, year: 1990, theme: 'אופנה וביטוי עצמי', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 9,
      title: 'שלב 9 - ישראלי חדש (2024–2025)',
      songs: [
        Song(title: 'Hurricane', artist: 'Eden Golan', language: Language.english, year: 2024, theme: 'סופה פנימית', isBand: false),
        Song(title: 'רוקי', artist: 'אודיה', language: Language.hebrew, year: 2024, theme: 'כוח ולחימה', isBand: false),
        Song(title: 'היא לא יודעת למה', artist: 'פאר טסי', language: Language.hebrew, year: 2024, theme: 'אי הבנה באהבה', isBand: false),
        Song(title: 'אהבתי זה אתמול', artist: 'יונתן מרגי (Margie)', language: Language.hebrew, year: 2024, theme: 'אהבה שעברה', isBand: false),
        Song(title: 'בסיבוב הבא', artist: 'עדן בן זקן', language: Language.hebrew, year: 2024, theme: 'הזדמנות נוספת', isBand: false),
        Song(title: 'מליון קילומטר', artist: 'יסמין מועלם', language: Language.hebrew, year: 2024, theme: 'מרחק ואהבה', isBand: false),
        Song(title: 'אלייך', artist: 'אדיר גץ', language: Language.hebrew, year: 2024, theme: 'געגועים', isBand: false),
        Song(title: 'שב עליי', artist: 'רביב כנר', language: Language.hebrew, year: 2024, theme: 'תשוקה', isBand: false),
      ],
      isUnlocked: false,
    ),
    Level(
      index: 10,
      title: 'שלב 10 - אתגר אמיתי (ביצועי שירה)',
      songs: [
        Song(title: 'אין אותי', artist: 'נועה קירל', language: Language.hebrew, year: 2019, theme: 'עצמאות והישארות', isBand: false),
        Song(title: 'אם את כבר הולכת', artist: 'נדב חנציס', language: Language.hebrew, year: 2020, theme: 'פרידה', isBand: false),
        Song(title: 'הבלדה על סוסי', artist: 'אדיק', language: Language.hebrew, year: 2021, theme: 'סיפור אישי', isBand: false),
        Song(title: 'רגע מתוק', artist: 'דודו טסה', language: Language.hebrew, year: 2018, theme: 'רגע קסום', isBand: false),
        Song(title: 'סיבת הסיבות', artist: 'ישי ריבו', language: Language.hebrew, year: 2016, theme: 'אמונה ותודה', isBand: false),
        Song(title: 'מתנות קטנות', artist: 'רן דנקר', language: Language.hebrew, year: 2017, theme: 'הערכה לדברים קטנים', isBand: false),
        Song(title: 'שיר אהבה בדואי', artist: 'רונית שחר', language: Language.hebrew, year: 1984, theme: 'אהבה במדבר', isBand: false),
        Song(title: 'Perfect', artist: 'Ed Sheeran', language: Language.english, year: 2017, theme: 'אהבה מושלמת', isBand: false),
      ],
      isUnlocked: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedProgress();
    _preloadFirstSong();
    if (!kIsWeb) {
      _loadInterstitialAd();
    }
  }

  Future<void> _loadSavedProgress() async {
    try {
      final solvedSongs = await UserDataHelper.getSolvedSongs().timeout(const Duration(seconds: 2));
      for (int levelIndex = 0; levelIndex < levels.length; levelIndex++) {
        final level = levels[levelIndex];
        for (int songIndex = 0; songIndex < level.songs.length; songIndex++) {
          final songKey = UserDataHelper.getSongKey(level.index, songIndex);
          if (solvedSongs[songKey] == true) {
            level.songs[songIndex].isSolved = true;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (kIsWeb) return;
    if (_isAdLoaded && _interstitialAd != null) {
      AnalyticsHelper.logAdShown(adType: 'interstitial', trigger: 'level_complete');
      _interstitialAd!.show();
      _isAdLoaded = false;
    } else {
      AnalyticsHelper.logAdFailedToShow(adType: 'interstitial', error: 'Ad not loaded');
    }
  }

  Future<void> _preloadFirstSong() async {
    final unlockedLevel = levels.firstWhere((level) => level.isUnlocked, orElse: () => levels.first);
    final firstUnsolved = unlockedLevel.songs.firstWhere((s) => !s.isSolved, orElse: () => unlockedLevel.songs.first);
    if (firstUnsolved.previewUrl == null) {
      final cached = PreviewCache.get(firstUnsolved.title, firstUnsolved.artist);
      if (cached != null) {
        firstUnsolved.previewUrl = cached;
      } else {
        final url = await fetchItunesPreview(firstUnsolved.title, firstUnsolved.artist);
        if (url != null) {
          firstUnsolved.previewUrl = url;
          PreviewCache.set(firstUnsolved.title, firstUnsolved.artist, url);
        }
      }
    }
  }

  void _openLevel(Level level) async {
    if (!level.isUnlocked) return;
    await AnalyticsHelper.logLevelSelected(level.index, level.title);
    final needed = (level.songs.length * 0.7).ceil();
    final before = level.solvedCount;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongSelectionPage(
          score: widget.score,
          level: level,
          onScoreUpdate: (delta) => widget.score.value += delta,
          onLevelProgress: (updated) {
            final need = (updated.songs.length * 0.7).ceil();
            if (updated.solvedCount >= need) {
              final idx = levels.indexWhere((l) => l.index == updated.index);
              if (idx >= 0 && idx + 1 < levels.length) {
                setState(() => levels[idx + 1].isUnlocked = true);
              }
            }
          },
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});

    final after = level.solvedCount;
    if (before < needed && after >= needed) {
      AnalyticsHelper.logLevelCompleted(levelIndex: level.index, levelTitle: level.title, totalPoints: widget.score.value);
      Future.delayed(const Duration(milliseconds: 500), _showInterstitialAd);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ניחוש שירים', textAlign: TextAlign.center),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: Stack(
        children: [
          const _AppleDarkBackground(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: levels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final level = levels[i];
                      return InkWell(
                        onTap: () => _openLevel(level),
                        borderRadius: BorderRadius.circular(20),
                        child: GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(level.title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${level.solvedCount}/${level.songs.length}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[300], fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                level.isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                color: level.isUnlocked ? Colors.greenAccent : Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================
   SONG SELECTION
   ========================= */
class SongSelectionPage extends StatefulWidget {
  final ValueNotifier<int> score;
  final Level level;
  final ValueChanged<int> onScoreUpdate;
  final ValueChanged<Level> onLevelProgress;

  const SongSelectionPage({
    super.key,
    required this.score,
    required this.level,
    required this.onScoreUpdate,
    required this.onLevelProgress,
  });

  @override
  State<SongSelectionPage> createState() => _SongSelectionPageState();
}

class _SongSelectionPageState extends State<SongSelectionPage> {
  late Level level;
  bool _isLoadingPreviews = true;

  @override
  void initState() {
    super.initState();
    level = widget.level;
    _preloadPreviews();
  }

  Future<void> _preloadPreviews() async {
    final firstUnsolved = level.songs.firstWhere((s) => !s.isSolved, orElse: () => level.songs.first);
    if (firstUnsolved.previewUrl == null) {
      final cached = PreviewCache.get(firstUnsolved.title, firstUnsolved.artist);
      if (cached != null) {
        firstUnsolved.previewUrl = cached;
      } else {
        final url = await fetchItunesPreview(firstUnsolved.title, firstUnsolved.artist);
        if (url != null) {
          firstUnsolved.previewUrl = url;
          PreviewCache.set(firstUnsolved.title, firstUnsolved.artist, url);
        }
      }
    }
    for (final s in level.songs) {
      if (s != firstUnsolved && s.previewUrl == null) {
        final cached = PreviewCache.get(s.title, s.artist);
        if (cached != null) {
          s.previewUrl = cached;
        } else {
          final url = await fetchItunesPreview(s.title, s.artist);
          if (url != null) {
            s.previewUrl = url;
            PreviewCache.set(s.title, s.artist, url);
          }
        }
      }
    }
    if (mounted) setState(() => _isLoadingPreviews = false);
  }

  void _openSong(int index) async {
    if (level.songs[index].isSolved) {
      _showAlreadySolvedDialog();
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePlayPage(
          score: widget.score,
          level: level,
          songIndex: index,
          onSolved: (points) async {
            widget.onScoreUpdate(points);
            level.songs[index].isSolved = true;
            widget.onLevelProgress(level);
            final solvedSongs = await UserDataHelper.getSolvedSongs();
            final songKey = UserDataHelper.getSongKey(level.index, index);
            solvedSongs[songKey] = true;
            await UserDataHelper.saveSolvedSongs(solvedSongs);
            await UserDataHelper.saveScore(widget.score.value);
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {});
      if (result is int && result >= 0 && result < level.songs.length) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _openSong(result);
        }
      }
    }
  }

  void _showAlreadySolvedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F).withOpacity(0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.greenAccent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 100),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text('!כבר ניחשת את השיר הזה',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songs = level.songs;
    return Scaffold(
      appBar: AppBar(
        title: Text(level.title, textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: Stack(
        children: [
          const _AppleDarkBackground(),
          _isLoadingPreviews
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('...טוען שירים', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ]),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: songs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final song = songs[i];
                          final isDone = song.isSolved;
                          return InkWell(
                            onTap: () => _openSong(i),
                            borderRadius: BorderRadius.circular(20),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.music_note, color: Colors.white70),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text('שיר ${i + 1}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  ),
                                  Icon(isDone ? Icons.check_circle : Icons.play_circle_fill,
                                      color: isDone ? Colors.greenAccent : Colors.white),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

/* =========================
   GAME PLAY – Upgraded Hints
   ========================= */
class GamePlayPage extends StatefulWidget {
  final ValueNotifier<int> score;
  final Level level;
  final int songIndex;
  final ValueChanged<int> onSolved;

  const GamePlayPage({
    super.key,
    required this.score,
    required this.level,
    required this.songIndex,
    required this.onSolved,
  });

  @override
  State<GamePlayPage> createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<GamePlayPage> {
  final FocusNode _inputFocus = FocusNode();
  late Song song;
  final _controller = TextEditingController();
  final _player = AudioFx.player;

  bool isLoadingSong = false;
  bool isLoadingPlay = false;
  bool isPlaying = false;
  int exposureSeconds = 1; // 1..30
  DateTime? startTime;
  int attempts = 0;

  // upgraded hints
  final List<int> hintCosts = [40, 60, 80]; // a bit steeper for better hints
  int hintsUsed = 0;
  final List<String> shownHints = [];

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  @override
  void initState() {
    super.initState();
    song = widget.level.songs[widget.songIndex];
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => isPlaying = s == PlayerState.playing);
    });
    _ensurePreview();
    if (!kIsWeb) {
      _loadRewardedAd();
    }
  }

  @override
  void dispose() {
    _inputFocus.dispose();
    _controller.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadRewardedAd() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  Future<void> _ensurePreview() async {
    if (song.previewUrl != null) return;
    setState(() => isLoadingSong = true);
    final cached = PreviewCache.get(song.title, song.artist);
    if (cached != null) {
      song.previewUrl = cached;
      setState(() => isLoadingSong = false);
      return;
    }
    final previewUrl = await fetchItunesPreview(song.title, song.artist);
    if (previewUrl != null) {
      song.previewUrl = previewUrl;
      PreviewCache.set(song.title, song.artist, previewUrl);
    } else {
      song.previewUrl = null;
    }
    setState(() => isLoadingSong = false);
  }

  Future<void> _playClip() async {
    final needsLoading = song.previewUrl == null;
    if (needsLoading) setState(() => isLoadingPlay = true);
    await _ensurePreview();
    if (song.previewUrl == null) {
      setState(() => isLoadingPlay = false);
      _snack('לא נמצא קטע תצוגה לשיר הזה 😢 נסי שיר אחר או דלגי');
      return;
    }
    startTime ??= DateTime.now();

    AnalyticsHelper.logSongPlayed(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      exposureSeconds: exposureSeconds,
    );

    await _player.stop();
    await _player.setSourceUrl(song.previewUrl!);
    await _player.seek(Duration.zero);
    await _player.resume();

    if (needsLoading) setState(() => isLoadingPlay = false);
    Future.delayed(Duration(seconds: exposureSeconds), () async {
      await _player.pause();
    });
  }

  Future<void> _stop() async => _player.stop();

  void _increaseExposure() {
    if (exposureSeconds < 30) setState(() => exposureSeconds++);
  }

  // NEW: smarter, more fun hints set
  String _getHintText() {
    final title = song.title;
    final artist = song.artist;
    final year = song.year;
    final theme = song.theme;
    final isBand = song.isBand;

    final firstWord = title.split(' ').first;
    final syllables = title.split(RegExp(r'[\s\-_]')).where((s) => s.isNotEmpty).toList();
    final titleMasked = title.replaceAll(RegExp('[A-Za-zא-ת]'), '▮');

    if (hintsUsed == 0) {
      // Easy: genre/meta/soft mask
      final parts = <String>[];
      if (isBand != null) parts.add(isBand ? 'זו להקה' : 'זה אמן/ית סולו');
      if (year != null) parts.add('השיר יצא בשנת $year');
      if (theme != null) parts.add('הנושא: $theme');
      if (parts.isEmpty) parts.add('השם מתחיל במילה "$firstWord"');
      return 'רמז קל: ${parts.join(' • ')}';
    } else if (hintsUsed == 1) {
      // Medium: playful transformations
      //  - acrostic: first letters of up to 3 words
      final acrostic = syllables.take(3).map((w) => w.characters.first).join('');
      //  - emoji hint based on theme
      String emoji = '🎵';
      if ((theme ?? '').contains('אהבה')) emoji = '❤️';
      else if ((theme ?? '').contains('מסיבה')) emoji = '🎉';
      else if ((theme ?? '').contains('זמן')) emoji = '⏳';
      else if ((theme ?? '').contains('כוח')) emoji = '💪';
      return 'רמז בינוני: האמן/ית – $artist · ראשי תיבות: $acrostic · $emoji';
    } else {
      // Hard: masked title with revealed head & length
      final headLen = (title.length >= 3) ? 3 : title.length;
      final head = title.substring(0, headLen);
      final mask = '${head}${"•" * (title.length - headLen)}';
      return 'רמז מתקדם: $mask  (אורך ${title.length} תווים)';
    }
  }

  void _useHint() {
    if (hintsUsed >= 3) return;
    final cost = hintCosts[hintsUsed];
    if (widget.score.value < cost) {
      _snack('אין לך מספיק נקודות! צפי בפרסומת לקבל רמז 📺');
      return;
    }
    final hint = _getHintText();
    AnalyticsHelper.logHintUsed(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      hintType: 'points',
      hintNumber: hintsUsed + 1,
      cost: cost,
    );
    setState(() {
      widget.score.value -= cost;
      hintsUsed++;
      shownHints.add('(-$cost) $hint');
    });
  }

  void _watchAdForHint() {
    if (kIsWeb) {
      _snack('פרסומות זמינות רק באפליקציה 📱');
      return;
    }
    if (hintsUsed >= 3) {
      _snack('השתמשת בכל הרמזים! 🎯');
      return;
    }
    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      _snack('הפרסומת טוענת... נסי שוב בעוד רגע ⏳');
      return;
    }
    AnalyticsHelper.logAdShown(adType: 'rewarded', trigger: 'hint_request');
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      final hint = _getHintText();
      AnalyticsHelper.logHintUsed(
        levelIndex: widget.level.index,
        songIndex: widget.songIndex,
        hintType: 'ad',
        hintNumber: hintsUsed + 1,
        cost: null,
      );
      setState(() {
        hintsUsed++;
        shownHints.add('(📺 פרסומת) $hint');
      });
    });
    _isRewardedAdLoaded = false;
  }

  void _checkAnswer() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    attempts++;

    final ok = isTitleMatch(input, song.title);
    if (!ok) {
      _snack('לא נכון, נסי שוב 🎧');
      return;
    }

    final elapsed = startTime == null ? 0 : DateTime.now().difference(startTime!).inSeconds;
    int points = 100 - (exposureSeconds * 2) - elapsed - (hintsUsed > 0 ? hintCosts.take(hintsUsed).reduce((a, b) => a + b) : 0);
    final bonusFirstAttempt = attempts == 1 ? 10 : 0;
    if (attempts == 1) points += 10;
    if (points < 10) points = 10;

    AnalyticsHelper.logSongSolved(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      points: points,
      attempts: attempts,
      hintsUsed: hintsUsed,
      timeSeconds: elapsed,
    );

    final hintPenalty = hintsUsed > 0 ? hintCosts.take(hintsUsed).reduce((a, b) => a + b) : 0;
    final exposurePenalty = exposureSeconds * 2;
    final timePenalty = elapsed;

    String scoreBreakdown = '100 נקודות בסיס';
    if (exposurePenalty > 0) scoreBreakdown += '\n-$exposurePenalty שניות חשיפה';
    if (timePenalty > 0) scoreBreakdown += '\n-$timePenalty זמן חשיבה';
    if (hintPenalty > 0) scoreBreakdown += '\n-$hintPenalty רמזים';
    if (bonusFirstAttempt > 0) scoreBreakdown += '\n+$bonusFirstAttempt ניחוש ראשון!';

    int? nextUnsolvedIndex;
    for (int i = widget.songIndex + 1; i < widget.level.songs.length; i++) {
      if (!widget.level.songs[i].isSolved) { nextUnsolvedIndex = i; break; }
    }
    if (nextUnsolvedIndex == null) {
      for (int i = 0; i < widget.songIndex; i++) {
        if (!widget.level.songs[i].isSolved) { nextUnsolvedIndex = i; break; }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('!כל הכבוד 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${song.title} - ${song.artist}\n\n$scoreBreakdown\n\nסה״כ: +$points נקודות',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (nextUnsolvedIndex != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSolved(points);
                Navigator.pop(context, nextUnsolvedIndex);
              },
              child: const Text('שיר הבא ➡️', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSolved(points);
              Navigator.pop(context, true);
            },
            child: Text(nextUnsolvedIndex != null ? 'חזרה לשלב' : 'חזרה', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  void _skipSong() {
    AnalyticsHelper.logSongSkipped(levelIndex: widget.level.index, songIndex: widget.songIndex, attempts: attempts);
    final currentLevel = widget.level;

    int? nextUnsolvedIndex;
    for (int i = widget.songIndex + 1; i < currentLevel.songs.length; i++) {
      if (!currentLevel.songs[i].isSolved) { nextUnsolvedIndex = i; break; }
    }
    if (nextUnsolvedIndex == null) {
      for (int i = 0; i < widget.songIndex; i++) {
        if (!currentLevel.songs[i].isSolved) { nextUnsolvedIndex = i; break; }
      }
    }

    if (nextUnsolvedIndex != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePlayPage(
            score: widget.score,
            level: currentLevel,
            songIndex: nextUnsolvedIndex!,
            onSolved: widget.onSolved,
          ),
        ),
      );
    } else {
      _snack('כל השירים בשלב זה נפתרו! חזרי למסך השלבים לבחור שלב חדש 🎉');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('נחשי את השיר', textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            const _AppleDarkBackground(),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Text('שלב ${widget.level.index} · שיר ${widget.songIndex + 1}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _circleBtn(isPlaying ? Icons.stop : Icons.play_arrow, isPlaying ? _stop : _playClip, null),
                            const SizedBox(width: 14),
                            _circleBtnWithBadge(Icons.add, _increaseExposure, '${exposureSeconds}s', label: '+1sec'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isLoadingSong || isLoadingPlay) ...[
                          const SizedBox(height: 6),
                          const SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator(color: Color(0xFF0A84FF), strokeWidth: 3),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text('Music previews by iTunes',
                            style: TextStyle(fontSize: 9, color: Colors.white38, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _inputFocus,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '...הקלידי את שם השיר',
                            hintStyle: const TextStyle(fontSize: 14),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                          ),
                          onSubmitted: (_) => _checkAnswer(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _checkAnswer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.check_circle, size: 30),
                                label: const Text(''),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _skipSong,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orangeAccent, width: 2),
                                  foregroundColor: Colors.orangeAccent,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.skip_next, size: 30),
                                label: const Text(''),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        if (shownHints.isNotEmpty)
                          ...shownHints.map((h) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('💡 $h', textAlign: TextAlign.center),
                              )),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<int>(
                          valueListenable: widget.score,
                          builder: (context, score, _) {
                            final cost = hintsUsed < 3 ? hintCosts[hintsUsed] : 0;
                            final canAfford = score >= cost && hintsUsed < 3;
                            return kIsWeb
                                ? Center(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: (hintsUsed >= 3 || !canAfford) ? null : _useHint,
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: canAfford ? Colors.orangeAccent : Colors.grey, width: 2),
                                          foregroundColor: canAfford ? Colors.orangeAccent : Colors.grey,
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        ),
                                        icon: Icon(Icons.lightbulb, color: canAfford ? Colors.orangeAccent : Colors.grey, size: 20),
                                        label: Text(hintsUsed >= 3 ? 'אזלו הרמזים' : 'רמז ($cost נקודות)', style: const TextStyle(fontSize: 14)),
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: (hintsUsed >= 3 || !canAfford) ? null : _useHint,
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: canAfford ? Colors.orangeAccent : Colors.grey, width: 2),
                                            foregroundColor: canAfford ? Colors.orangeAccent : Colors.grey,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          ),
                                          icon: Icon(Icons.lightbulb, color: canAfford ? Colors.orangeAccent : Colors.grey, size: 20),
                                          label: Text(hintsUsed >= 3 ? 'אזלו' : '$cost נק\'', style: const TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: hintsUsed >= 3 ? null : _watchAdForHint,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hintsUsed >= 3 ? Colors.grey : const Color(0xFF7836FF),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          ),
                                          icon: const Icon(Icons.play_circle_filled, size: 20),
                                          label: const Text('צפה בפרסומת', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, String? badge, {String? label}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF0A84FF), Color(0xFF64D2FF)]),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black54)],
        ),
        child: Center(
          child: label != null
              ? Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black))
              : Icon(icon, size: 26, color: Colors.black),
        ),
      ),
    );
  }

  Widget _circleBtnWithBadge(IconData icon, VoidCallback onTap, String badge, {String? label}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _circleBtn(icon, onTap, null, label: label),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF64D2FF),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: const Color(0xFF64D2FF).withOpacity(0.5), blurRadius: 6)],
            ),
            child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        ),
      ],
    );
  }
}
