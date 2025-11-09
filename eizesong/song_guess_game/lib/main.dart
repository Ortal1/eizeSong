import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
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
      // Preload/buffer: set source, start quietly, then pause.
      await player.setSourceUrl(url);
      await player.setVolume(0);
      await player.resume();
      await Future.delayed(const Duration(milliseconds: 150));
      await player.pause();
      await player.setVolume(1);
    } catch (_) {}
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Only initialize Mobile Ads on mobile platforms (not web)
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
  // Global score notifier so all screens can read & update.
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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: SplashPage(score: _score),
    );
  }
}

/* =========================
   REUSABLE UI PRIMITIVES
   ========================= */

/// Animated multi-color gradient background with subtle moving glow orbs.
class AnimatedGradientBackground extends StatelessWidget {
  final Widget child;
  const AnimatedGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 18),
      curve: Curves.linear,
      onEnd: () {},
      builder: (context, value, _) {
        return Stack(
          children: [
            // Base animated gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + value, -1),
                    end: Alignment(1, 1 - value),
                    colors: const [
                      Color(0xFF0f0c29),
                      Color(0xFF302b63),
                      Color(0xFF24243e),
                    ],
                  ),
                ),
              ),
            ),
            // Floating glow blobs
            Positioned.fill(
              child: CustomPaint(
                painter: _GlowBlobsPainter(progress: value),
              ),
            ),
            // Soft blur to blend
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.15)),
              ),
            ),
            // Foreground content
            Positioned.fill(child: child),
          ],
        );
      },
    );
  }
}

class _GlowBlobsPainter extends CustomPainter {
  final double progress;
  _GlowBlobsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paints = <Paint>[
      Paint()..color = const Color(0xFF00E5FF).withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
      Paint()..color = const Color(0xFF7C4DFF).withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
      Paint()..color = const Color(0xFFFF4081).withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    ];
    final centers = <Offset>[
      Offset(size.width * (0.2 + 0.1 * progress), size.height * 0.3),
      Offset(size.width * (0.8 - 0.1 * progress), size.height * 0.4),
      Offset(size.width * (0.5 + 0.05 * progress), size.height * 0.8),
    ];
    final radii = <double>[180, 220, 200];
    for (int i = 0; i < paints.length; i++) {
      canvas.drawCircle(centers[i], radii[i], paints[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowBlobsPainter oldDelegate) => true;
}

/// Glassmorphism card
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
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        color: Colors.white.withOpacity(0.08),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }
}

/// Neon-styled primary button
class NeonButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  const NeonButton({super.key, required this.onPressed, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D1FF),
          foregroundColor: Colors.black,
          elevation: 12,
          shadowColor: const Color(0xFF00D1FF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ).merge(ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.15)),
        )),
      ),
    );
  }
}

/// Score badge (top-right)
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
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.45),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.black, size: 18),
              const SizedBox(width: 6),
              Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Cheaper (no blur) background for performance-sensitive screens.
class CheapBackground extends StatelessWidget {
  final Widget child;
  const CheapBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 18),
      curve: Curves.linear,
      builder: (context, value, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + value, -1),
                    end: Alignment(1, 1 - value),
                    colors: const [
                      Color(0xFF0f0c29),
                      Color(0xFF302b63),
                      Color(0xFF24243e),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ],
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

  Song({
    required this.title,
    required this.artist,
    required this.language,
    this.previewUrl,
    this.isSolved = false,
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

  // Exact match
  if (a == b) return true;

  // Allow if user input is at least 70% of the expected length
  // and the expected title contains the user input
  if (a.length >= (b.length * 0.7) && b.contains(a)) {
    return true;
  }

  return false;
}

/// Fetches preview URL from iTunes Search API
Future<String?> fetchItunesPreview(String title, String artist) async {
  try {
    final q = Uri.encodeQueryComponent('$artist $title');
    final uri = Uri.parse('https://itunes.apple.com/search?term=$q&entity=song&limit=5&country=IL');

    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    if (results.isEmpty) return null;

    // Find best match
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

    // Fallback: first result with preview
    for (final r in results) {
      if (r['previewUrl'] != null) {
        return r['previewUrl'] as String;
      }
    }

    return null;
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ [ITUNES] Error: $e');
    }
    return null;
  }
}

/* =========================
   SPLASH PAGE (מסך פתיחה) – הכל ממורכז
   ========================= */
class SplashPage extends StatefulWidget {
  final ValueNotifier<int> score;
  const SplashPage({super.key, required this.score});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.92,
      upperBound: 1.04,
    )..repeat(reverse: true);
    _pulse = _controller.drive(Tween<double>(begin: 0.92, end: 1.04));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LevelSelectionPage(score: widget.score),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        elevation: 0,
        centerTitle: true,
        title: const Text('ניחוש שירים', textAlign: TextAlign.center),
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: Container(
        color: const Color(0xFF1a1a2e), // Simple solid color instead of gradient
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 96, color: Colors.white70),
                      const SizedBox(height: 10),
                      const Text('ברוכה הבאה ואם שבה אז שווה', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _start(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('התחילי', textAlign: TextAlign.center),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* =========================
   LEVEL SELECTION – ממורכז, כרטיסי זכוכית
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
    // 1
    Level(
      index: 1,
      title: 'שלב לאה - שירי קאלט משנות ה-70 וה-80',
      songs: [
        Song(title: 'Bohemian Rhapsody', artist: 'Queen', language: Language.english),
        Song(title: 'Hotel California', artist: 'Eagles', language: Language.english),
        Song(title: 'Stairway to Heaven', artist: 'Led Zeppelin', language: Language.english),
        Song(title: 'Imagine', artist: 'John Lennon', language: Language.english),
        Song(title: 'Don\'t Stop Believin\'', artist: 'Journey', language: Language.english),
        Song(title: 'Sweet Child O\' Mine', artist: 'Guns N\' Roses', language: Language.english),
        Song(title: 'Billie Jean', artist: 'Michael Jackson', language: Language.english),
        Song(title: 'Stayin\' Alive', artist: 'Bee Gees', language: Language.english),
        Song(title: 'I Will Survive', artist: 'Gloria Gaynor', language: Language.english),
        Song(title: 'Africa', artist: 'Toto', language: Language.english),
        Song(title: 'Livin\' on a Prayer', artist: 'Bon Jovi', language: Language.english),
        Song(title: 'Sweet Dreams', artist: 'Eurythmics', language: Language.english),
        Song(title: 'Take On Me', artist: 'a-ha', language: Language.english),
        Song(title: 'Every Breath You Take', artist: 'The Police', language: Language.english),
        Song(title: 'With or Without You', artist: 'U2', language: Language.english),
        Song(title: 'Careless Whisper', artist: 'George Michael', language: Language.english),
        Song(title: 'Beat It', artist: 'Michael Jackson', language: Language.english),
        Song(title: 'Purple Rain', artist: 'Prince', language: Language.english),
        Song(title: 'Eye of the Tiger', artist: 'Survivor', language: Language.english),
        Song(title: 'Girls Just Want to Have Fun', artist: 'Cyndi Lauper', language: Language.english),
      ],
      isUnlocked: true,
    ),

    // 2
    Level(
      index: 2,
      title: 'שלב 2 - פופ ישראלי',
      songs: [
        Song(title: 'נובמבר', artist: 'מירי מסיקה', language: Language.hebrew),
        Song(title: 'עד הקצה', artist: 'דנה ברגר', language: Language.hebrew),
        Song(title: 'השקט שנשאר', artist: 'שירי מימון', language: Language.hebrew),
        Song(title: 'הלב', artist: 'מאיה בוסקילה', language: Language.hebrew),
        Song(title: 'מלכת הדור', artist: 'עומר אדם', language: Language.hebrew),
        Song(title: 'כמה עוד אפשר', artist: 'הראל סקעת', language: Language.hebrew),
        Song(title:'מבול', artist: 'קרן פלס', language: Language.hebrew),
      ],
      isUnlocked: false,
    ),

    // 3
    Level(
      index: 3,
      title: 'שלב 3 - רוק ומזרחי',
      songs: [
        Song(title: 'טקילה', artist: 'עומר אדם', language: Language.hebrew),
        Song(title: 'חולות של תל אביב', artist: 'אושר כהן', language: Language.hebrew),
        Song(title: 'זמן שזז', artist: 'עידן עמדי', language: Language.hebrew),
        Song(title: 'רצים באדום', artist: 'תובל שפיר', language: Language.hebrew),
        Song(title: 'מתי נתנשק', artist: 'ישיר', language: Language.hebrew),
        Song(title: 'דבר אליי', artist: 'אייל גולן', language: Language.hebrew),
        Song(title: 'ים של דמעות', artist: 'זהבה בן', language: Language.hebrew),
        Song(title: 'אינטואיציה', artist: 'גדי צלניקר', language: Language.hebrew),
      ],
      isUnlocked: false,
    ),

    // 4
    Level(
      index: 4,
      title: 'שלב 4 - היטים עולמיים עדכניים',
      songs: [
        Song(title: 'Not Like Us', artist: 'Kendrick Lamar', language: Language.english),
        Song(title: 'Espresso', artist: 'Sabrina Carpenter', language: Language.english),
        Song(title: 'Beautiful Things', artist: 'Benson Boone', language: Language.english),
        Song(title: 'A Bar Song (Tipsy)', artist: 'Shaboozey', language: Language.english),
        Song(title: 'Houdini', artist: 'Dua Lipa', language: Language.english),
        Song(title: 'As It Was', artist: 'Harry Styles', language: Language.english),
        Song(title: 'Flowers', artist: 'Miley Cyrus', language: Language.english),
        Song(title: 'Anti-Hero', artist: 'Taylor Swift', language: Language.english),
      ],
      isUnlocked: false,
    ),

    // 5
    Level(
      index: 5,
      title: 'שלב 5 - שירי זמר (ישראליות נצחיות)',
      songs: [
        Song(title: 'לו יהי', artist: 'נעמי שמר', language: Language.hebrew),
        Song(title: 'אוף גוזל', artist: 'אריק איינשטיין', language: Language.hebrew),
        Song(title: 'פתאום', artist: 'יהודית רביץ', language: Language.hebrew),
        Song(title: 'שיר לשלום', artist: 'מירי אלוני', language: Language.hebrew),
        Song(title: 'הבלדה על חדוה ושלומיק', artist: 'שלום חנוך', language: Language.hebrew),
        Song(title: 'רחוב האגס 1', artist: 'להקת כוורת', language: Language.hebrew),
        Song(title: 'אני ואתה', artist: 'אריק איינשטיין', language: Language.hebrew), // ← אם תרצי, אוכל להחליף כדי לשמור בלי כפילויות אמנים בכלל בשלבים
        Song(title: 'יש כוכבים', artist: 'נורית גלרון', language: Language.hebrew),
      ],
      isUnlocked: false,
    ),

    // 6
    Level(
      index: 6,
      title: 'שלב 6 - דאנס ואלקטרוני',
      songs: [
        Song(title: 'Wake Me Up', artist: 'Avicii', language: Language.english),
        Song(title: 'One Kiss', artist: 'Calvin Harris', language: Language.english),
        Song(title: 'Head & Heart', artist: 'Joel Corry', language: Language.english),
        Song(title: 'I\'m Good (Blue)', artist: 'David Guetta', language: Language.english),
        Song(title: 'Closer', artist: 'The Chainsmokers', language: Language.english),
        Song(title: 'Despacito', artist: 'Luis Fonsi', language: Language.english),
        Song(title: 'Pepas', artist: 'Farruko', language: Language.english),
        Song(title: 'Titanium', artist: 'David Guetta ft Sia', language: Language.english),
      ],
      isUnlocked: false,
    ),

    // 7
    Level(
      index: 7,
      title: 'שלב 7 - היפ הופ ו-R&B',
      songs: [
        Song(title: 'Lose Yourself', artist: 'Eminem', language: Language.english),
        Song(title: 'In Da Club', artist: '50 Cent', language: Language.english),
        Song(title: 'Hotline Bling', artist: 'Drake', language: Language.english),
        Song(title: 'HUMBLE.', artist: 'Kendrick Lamar', language: Language.english),
        Song(title: 'Crazy in Love', artist: 'Beyoncé', language: Language.english),
        Song(title: 'Umbrella', artist: 'Rihanna', language: Language.english),
        Song(title: 'Gold Digger', artist: 'Kanye West', language: Language.english),
        Song(title: 'See You Again', artist: 'Wiz Khalifa', language: Language.english),
      ],
      isUnlocked: false,
    ),

    // 8
    Level(
      index: 8,
      title: 'שלב 8 - שנות ה-80 וה-90',
      songs: [
        Song(title: 'Take On Me', artist: 'a-ha', language: Language.english),
        Song(title: 'Livin\' on a Prayer', artist: 'Bon Jovi', language: Language.english),
        Song(title: 'Sweet Dreams', artist: 'Eurythmics', language: Language.english),
        Song(title: 'Every Breath You Take', artist: 'The Police', language: Language.english),
        Song(title: 'Wonderwall', artist: 'Oasis', language: Language.english),
        Song(title: 'Baby One More Time', artist: 'Britney Spears', language: Language.english),
        Song(title: 'Wannabe', artist: 'Spice Girls', language: Language.english),
        Song(title: 'Vogue', artist: 'Madonna', language: Language.english),
      ],
      isUnlocked: false,
    ),

    // 9
    Level(
      index: 9,
      title: 'שלב 9 - ישראלי חדש (2024–2025)',
      songs: [
        Song(title: 'Hurricane', artist: 'Eden Golan', language: Language.english), // אמנית ישראלית, שיר באנגלית
        Song(title: 'רוקי', artist: 'אודיה', language: Language.hebrew),
        Song(title: 'היא לא יודעת למה', artist: 'פאר טסי', language: Language.hebrew),
        Song(title: 'אהבתי זה אתמול', artist: 'יונתן מרגי (Margie)', language: Language.hebrew),
        Song(title: 'בסיבוב הבא', artist: 'עדן בן זקן', language: Language.hebrew),
        Song(title: 'מליון קילומטר', artist: 'יסמין מועלם', language: Language.hebrew),
        Song(title: 'אלייך', artist: 'אדיר גץ', language: Language.hebrew),
        Song(title: 'שב עליי', artist: 'רביב כנר', language: Language.hebrew),
      ],
      isUnlocked: false,
    ),

    // 10
    Level(
      index: 10,
      title: 'שלב 10 - אתגר אמיתי (ביצועי שירה)',
      songs: [
        Song(title: 'אין אותי', artist: 'נועה קירל', language: Language.hebrew),
        Song(title: 'אם את כבר הולכת', artist: 'נדב חנציס', language: Language.hebrew),
        Song(title: 'הבלדה על סוסי', artist: 'אדיק', language: Language.hebrew),
        Song(title: 'רגע מתוק', artist: 'דודו טסה', language: Language.hebrew),
        Song(title: 'סיבת הסיבות', artist: 'ישי ריבו', language: Language.hebrew),
        Song(title: 'מתנות קטנות', artist: 'רן דנקר', language: Language.hebrew),
        Song(title: 'שיר אהבה בדואי', artist: 'רונית שחר', language: Language.hebrew),
        Song(title: 'Perfect', artist: 'Ed Sheeran', language: Language.english),
      ],
      isUnlocked: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Preload the first unsolved song from the first unlocked level
    _preloadFirstSong();
    // Load interstitial ad (only on mobile)
    if (!kIsWeb) {
      _loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    if (kIsWeb) return; // Skip on web
    print('🔄 Loading interstitial ad...');
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ Ad loaded successfully!');
          _interstitialAd = ad;
          _isAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('📱 Ad dismissed');
              ad.dispose();
              _loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ Ad failed to show: $error');
              ad.dispose();
              _loadInterstitialAd(); // Load next ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ Ad failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (kIsWeb) return; // Skip on web
    print('🎬 Attempting to show ad... isLoaded: $_isAdLoaded');
    if (_isAdLoaded && _interstitialAd != null) {
      print('✅ Showing ad now!');

      // Log analytics for ad shown
      AnalyticsHelper.logAdShown(
        adType: 'interstitial',
        trigger: 'level_complete',
      );

      _interstitialAd!.show();
      _isAdLoaded = false;
    } else {
      print('❌ Ad not ready. isLoaded: $_isAdLoaded, ad: $_interstitialAd');

      // Log analytics for ad failure
      AnalyticsHelper.logAdFailedToShow(
        adType: 'interstitial',
        error: 'Ad not loaded',
      );
    }
  }

  Future<void> _preloadFirstSong() async {
    // Find the first unlocked level
    final unlockedLevel = levels.firstWhere(
      (level) => level.isUnlocked,
      orElse: () => levels.first,
    );

    // Find the first unsolved song in that level
    final firstUnsolved = unlockedLevel.songs.firstWhere(
      (s) => !s.isSolved,
      orElse: () => unlockedLevel.songs.first,
    );

    // Preload the preview from iTunes
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

    // Log analytics
    await AnalyticsHelper.logLevelSelected(level.index, level.title);

    final needed = (level.songs.length * 0.7).ceil();
    final solvedCountBefore = level.solvedCount;
    print('📊 Opening level ${level.index}: needed=$needed, before=$solvedCountBefore');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongSelectionPage(
          score: widget.score,
          level: level,
          onScoreUpdate: (delta) => widget.score.value += delta,
          onLevelProgress: (updated) {
            final needed = (updated.songs.length * 0.7).ceil();
            if (updated.solvedCount >= needed) {
              final idx = levels.indexWhere((l) => l.index == updated.index);
              if (idx >= 0 && idx + 1 < levels.length) {
                setState(() => levels[idx + 1].isUnlocked = true);
              }
            }
          },
        ),
      ),
    );

    // עדכון המסך כשחוזרים
    if (mounted) {
      setState(() {});

      // הצגת פרסומת אם השלב הושלם
      final solvedCountAfter = level.solvedCount;
      print('📊 After level ${level.index}: needed=$needed, after=$solvedCountAfter');

      if (solvedCountBefore < needed && solvedCountAfter >= needed) {
        print('🎉 LEVEL COMPLETED! Showing ad in 500ms...');
        // Log level completion
        AnalyticsHelper.logLevelCompleted(
          levelIndex: level.index,
          levelTitle: level.title,
          totalPoints: widget.score.value,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          _showInterstitialAd();
        });
      } else {
        print('⏳ Level not completed yet. Before: $solvedCountBefore, After: $solvedCountAfter, Needed: $needed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ניחוש שירים', textAlign: TextAlign.center),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: CheapBackground(
        child: Padding(
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
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}

/* =========================
   SONG SELECTION – ממורכז
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
    // First, preload the first unsolved song for quick play
    final firstUnsolved = level.songs.firstWhere(
      (s) => !s.isSolved,
      orElse: () => level.songs.first,
    );

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

    // Then preload the rest in the background
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

    if (mounted) {
      setState(() {
        _isLoadingPreviews = false;
      });
    }
  }

  void _openSong(int index) async {
    // Don't open if already solved - show celebration instead
    if (level.songs[index].isSolved) {
      _showAlreadySolvedDialog();
      return;
    }

    // Show loading indicator while song screen loads
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    // Wait for loading indicator to show
    await Future.delayed(const Duration(milliseconds: 200));

    // Close loading dialog
    if (!mounted) return;
    Navigator.pop(context);

    // Small delay before opening song page
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate to the song page
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePlayPage(
          score: widget.score,
          level: level,
          songIndex: index,
          onSolved: (points) {
            widget.onScoreUpdate(points);
            level.songs[index].isSolved = true;
            widget.onLevelProgress(level);
          },
        ),
      ),
    );

    // רק אם באמת ניחשה נכון - נרענן
    if (result != null) {
      setState(() {});

      // אם התוצאה היא מספר (אינדקס של שיר הבא), פתחי אותו אוטומטית
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
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 100,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '!כבר ניחשת את השיר הזה',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(level.title, textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: CheapBackground(
        child: _isLoadingPreviews
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      '...טוען שירים',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
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
                                  child: Text(
                                    'שיר ${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Icon(
                                  isDone ? Icons.check_circle : Icons.play_circle_fill,
                                  color: isDone ? Colors.greenAccent : Colors.white,
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
    );
  }
}

/* =========================
   GAME PLAY – ממורכז + זכוכית
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
  bool isLoadingPlay = false; // Loading indicator for play button
  bool isPlaying = false;
  int exposureSeconds = 1; // 1..30
  DateTime? startTime;
  int attempts = 0;

  // hints
  final List<int> hintCosts = [5, 10, 10];
  int hintsUsed = 0;
  final List<String> shownHints = [];

  // Rewarded ad for hints
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  @override
  void initState() {
    super.initState();
    song = widget.level.songs[widget.songIndex];
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => isPlaying = s == PlayerState.playing);
    });
    // Preload song preview in background immediately
    _ensurePreview();
    // Load rewarded ad (only on mobile)
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
    if (kIsWeb) return; // Skip on web
    print('🎁 Loading rewarded ad...');
    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ Rewarded ad loaded!');
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('📱 Rewarded ad dismissed');
              ad.dispose();
              _loadRewardedAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ Rewarded ad failed to show: $error');
              ad.dispose();
              _loadRewardedAd(); // Load next ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ Rewarded ad failed to load: $error');
          _isRewardedAdLoaded = false;
        },
      ),
    );
  }

  Future<void> _ensurePreview() async {
    if (song.previewUrl != null) {
      if (kDebugMode) {
        print('🎵 [PREVIEW] Using cached preview for "${song.title}" by ${song.artist}');
      }
      return;
    }

    setState(() => isLoadingSong = true);

    final cached = PreviewCache.get(song.title, song.artist);
    if (cached != null) {
      song.previewUrl = cached;
      if (kDebugMode) {
        print('💾 [CACHE] Found cached preview for "${song.title}" by ${song.artist}');
      }
      setState(() => isLoadingSong = false);
      return;
    }

    // Fetch from iTunes
    if (kDebugMode) {
      print('🔍 [ITUNES] Searching iTunes for "${song.title}" by ${song.artist}');
    }
    final previewUrl = await fetchItunesPreview(song.title, song.artist);
    if (previewUrl != null) {
      song.previewUrl = previewUrl;
      PreviewCache.set(song.title, song.artist, previewUrl);
      if (kDebugMode) {
        print('✅ [ITUNES] Found preview on iTunes!');
        print('🔗 Preview URL: $previewUrl');
      }
    } else {
      if (kDebugMode) {
        print('❌ [ITUNES] No preview found on iTunes for "${song.title}" by ${song.artist}');
        print('⛔ Song will not be playable - iTunes preview required!');
      }
      song.previewUrl = null;
    }

    setState(() => isLoadingSong = false);
  }

  Future<void> _playClip() async {
    // Show loading indicator ONLY if preview not loaded yet
    final needsLoading = song.previewUrl == null;
    if (needsLoading) {
      setState(() => isLoadingPlay = true);
    }

    await _ensurePreview();
    if (song.previewUrl == null) {
      setState(() => isLoadingPlay = false);
      _snack('לא נמצא קטע תצוגה לשיר הזה 😢 נסי שיר אחר או דלגי');
      return;
    }
    startTime ??= DateTime.now();

    // Log analytics for song play
    AnalyticsHelper.logSongPlayed(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      exposureSeconds: exposureSeconds,
    );

    // Stop any current playback
    await _player.stop();

    // Set the source URL (from Spotify preview or fallback)
    await _player.setSourceUrl(song.previewUrl!);

    // Make sure we start from the beginning (0 seconds)
    await _player.seek(Duration.zero);

    // Start playing
    await _player.resume();

    // Hide loading indicator (only if we showed it)
    if (needsLoading) {
      setState(() => isLoadingPlay = false);
    }

    // Auto-stop after exposureSeconds
    Future.delayed(Duration(seconds: exposureSeconds), () async {
      await _player.pause();
    });
  }

  Future<void> _stop() async {
    await _player.stop();
  }

  void _increaseExposure() {
    if (exposureSeconds < 30) {
      setState(() => exposureSeconds++);
    }
  }

  String _getHintText() {
    if (hintsUsed == 0) {
      final firstWord = song.title.split(' ').first;
      return 'רמז: המילה הראשונה בשם השיר היא "$firstWord"';
    } else if (hintsUsed == 1) {
      return 'רמז: האמן/ת הוא/היא ${song.artist}';
    } else {
      final head = song.title.substring(0, song.title.length.clamp(0, 3));
      return 'רמז: תחילת השם כוללת "$head"';
    }
  }

  void _useHint() {
    if (hintsUsed >= 3) return;
    final cost = hintCosts[hintsUsed];

    // Check if user has enough points
    if (widget.score.value < cost) {
      _snack('אין לך מספיק נקודות! צפי בפרסומת לקבל רמז 📺');
      return;
    }

    final hint = _getHintText();

    // Log analytics for hint use
    AnalyticsHelper.logHintUsed(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      hintType: 'points',
      hintNumber: hintsUsed + 1,
      cost: cost,
    );

    setState(() {
      widget.score.value -= cost; // Deduct points
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

    print('🎁 Showing rewarded ad for hint...');

    // Log analytics for ad shown
    AnalyticsHelper.logAdShown(
      adType: 'rewarded',
      trigger: 'hint_request',
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print('✅ User earned reward! Giving hint...');
        final hint = _getHintText();

        // Log analytics for hint use via ad
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
      },
    );
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

    // Log analytics for song solved
    AnalyticsHelper.logSongSolved(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      points: points,
      attempts: attempts,
      hintsUsed: hintsUsed,
      timeSeconds: elapsed,
    );

    // Build score breakdown
    final hintPenalty = hintsUsed > 0 ? hintCosts.take(hintsUsed).reduce((a, b) => a + b) : 0;
    final exposurePenalty = exposureSeconds * 2;
    final timePenalty = elapsed;

    String scoreBreakdown = '100 נקודות בסיס';
    if (exposurePenalty > 0) scoreBreakdown += '\n-$exposurePenalty שניות חשיפה';
    if (timePenalty > 0) scoreBreakdown += '\n-$timePenalty זמן חשיבה';
    if (hintPenalty > 0) scoreBreakdown += '\n-$hintPenalty רמזים';
    if (bonusFirstAttempt > 0) scoreBreakdown += '\n+$bonusFirstAttempt ניחוש ראשון!';

    // Find next unsolved song starting from current song + 1
    int? nextUnsolvedIndex;

    // First, search from current song + 1 onwards
    for (int i = widget.songIndex + 1; i < widget.level.songs.length; i++) {
      if (!widget.level.songs[i].isSolved) {
        nextUnsolvedIndex = i;
        break;
      }
    }

    // If not found, wrap around and search from the beginning
    if (nextUnsolvedIndex == null) {
      for (int i = 0; i < widget.songIndex; i++) {
        if (!widget.level.songs[i].isSolved) {
          nextUnsolvedIndex = i;
          break;
        }
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
                Navigator.pop(context); // Close dialog
                widget.onSolved(points);
                // Return the next song index to automatically open it
                Navigator.pop(context, nextUnsolvedIndex);
              },
              child: const Text('שיר הבא ➡️', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onSolved(points);
              Navigator.pop(context, true); // Go back to song selection
            },
            child: Text(
              nextUnsolvedIndex != null ? 'חזרה לשלב' : 'חזרה',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _skipSong() {
    // Log analytics for song skip
    AnalyticsHelper.logSongSkipped(
      levelIndex: widget.level.index,
      songIndex: widget.songIndex,
      attempts: attempts,
    );

    final currentLevel = widget.level;

    // חיפוש שיר לא פתור אחרי הנוכחי
    int? nextUnsolvedIndex;
    for (int i = widget.songIndex + 1; i < currentLevel.songs.length; i++) {
      if (!currentLevel.songs[i].isSolved) {
        nextUnsolvedIndex = i;
        break;
      }
    }

    // אם לא מצאנו — חפשי מההתחלה
    if (nextUnsolvedIndex == null) {
      for (int i = 0; i < widget.songIndex; i++) {
        if (!currentLevel.songs[i].isSolved) {
          nextUnsolvedIndex = i;
          break;
        }
      }
    }

    if (nextUnsolvedIndex != null) {
      // דילוג לשיר הלא פתור הבא באותו שלב
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
      // כל השירים בשלב זה נפתרו — חזרה למסך בחירת השירים
      _snack('כל השירים בשלב זה נפתרו! חזרי למסך השלבים לבחור שלב חדש 🎉');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }


  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('נחשי את השיר', textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [ScoreBadge(score: widget.score)],
      ),
      body: GestureDetector(
        onTap: () {
          // Close keyboard when tapping outside text field
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: CheapBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // Level and Song Number Info - Centered
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    'שלב ${widget.level.index} · שיר ${widget.songIndex + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleBtn(
                          isPlaying ? Icons.stop : Icons.play_arrow,
                          isPlaying ? _stop : _playClip,
                          null,
                        ),
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
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                    // iTunes Attribution
                    const SizedBox(height: 8),
                    const Text(
                      'Music previews by iTunes',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Input field moved here
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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

              // Hint section moved down
              GlassCard(
                child: Column(
                  children: [
                    if (shownHints.isNotEmpty)
                      ...shownHints
                          .map((h) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('💡 $h', textAlign: TextAlign.center),
                              )),
                    const SizedBox(height: 10),
                    // Show current score
                    ValueListenableBuilder<int>(
                      valueListenable: widget.score,
                      builder: (context, score, _) {
                        final cost = hintsUsed < 3 ? hintCosts[hintsUsed] : 0;
                        final canAfford = score >= cost && hintsUsed < 3;

                        return kIsWeb
                            ?
                            // Web version - only points button, centered and wider
                            Center(
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: (hintsUsed >= 3 || !canAfford) ? null : _useHint,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: canAfford ? Colors.orangeAccent : Colors.grey,
                                      width: 2,
                                    ),
                                    foregroundColor: canAfford ? Colors.orangeAccent : Colors.grey,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  ),
                                  icon: Icon(
                                    Icons.lightbulb,
                                    color: canAfford ? Colors.orangeAccent : Colors.grey,
                                    size: 20,
                                  ),
                                  label: Text(
                                    hintsUsed >= 3 ? 'אזלו הרמזים' : 'רמז ($cost נקודות)',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            )
                            :
                            // Mobile version - both buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Use Points Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: (hintsUsed >= 3 || !canAfford) ? null : _useHint,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: canAfford ? Colors.orangeAccent : Colors.grey,
                                        width: 2,
                                      ),
                                      foregroundColor: canAfford ? Colors.orangeAccent : Colors.grey,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    ),
                                    icon: Icon(
                                      Icons.lightbulb,
                                      color: canAfford ? Colors.orangeAccent : Colors.grey,
                                      size: 20,
                                    ),
                                    label: Text(
                                      hintsUsed >= 3 ? 'אזלו' : '$cost נק\'',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Watch Ad Button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: hintsUsed >= 3 ? null : _watchAdForHint,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hintsUsed >= 3 ? Colors.grey : Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    ),
                                    icon: const Icon(Icons.play_circle_filled, size: 20),
                                    label: const Text(
                                      'צפה בפרסומת',
                                      style: TextStyle(fontSize: 12),
                                    ),
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
          gradient: LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
          ),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black54)],
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                )
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
              color: const Color(0xFF00E5FF),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
