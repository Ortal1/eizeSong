# פריסת האפליקציה ל-Netlify

## דרישות מקדימות
- חשבון Netlify (חינם ב-https://netlify.com)
- Flutter SDK מותקן במחשב (לבדיקה מקומית)
- Git repository (GitHub, GitLab, או Bitbucket)

## שלבי הפריסה

### 1. הכנת הפרויקט

הפרויקט כבר מוכן לפריסה ב-Netlify עם הקבצים הבאים:
- `netlify.toml` - קונפיגורציה של Netlify
- `build.sh` - סקריפט בנייה
- `web/_redirects` - ניתוב נכון של SPA

### 2. פריסה דרך Netlify Dashboard

#### אופציה 1: חיבור ל-Git Repository (מומלץ)

1. היכנסו ל-Netlify Dashboard: https://app.netlify.com
2. לחצו על "Add new site" → "Import an existing project"
3. בחרו את ספק ה-Git שלכם (GitHub/GitLab/Bitbucket)
4. בחרו את הריפוזיטורי של הפרויקט
5. הגדרות Build:
   - **Build command**: `flutter build web --release --web-renderer canvaskit`
   - **Publish directory**: `build/web`
   - **Base directory**: (השאירו ריק)
6. לחצו "Deploy site"

**חשוב**: Netlify צריך להתקין Flutter. תוכלו להשתמש ב-Build Plugin:
- עברו ל-Site settings → Build & deploy → Environment
- הוסיפו את ה-Plugin: `netlify-plugin-flutter`

#### אופציה 2: פריסה ידנית (לבדיקה)

1. בנו את הפרויקט מקומית:
```bash
flutter build web --release --web-renderer canvaskit
```

2. העלו את תיקיית `build/web` ידנית:
   - גררו את התיקייה `build/web` ל-Netlify Dashboard
   - או השתמשו ב-Netlify CLI:
```bash
npm install -g netlify-cli
netlify deploy --prod --dir=build/web
```

### 3. התקנת Flutter ב-Netlify Build Environment

#### שימוש ב-Build Plugin (מומלץ)

צרו קובץ `netlify.toml` (כבר קיים בפרויקט) עם:

```toml
[[plugins]]
  package = "netlify-plugin-flutter"
```

או התקינו ידנית:
1. Site settings → Build & deploy → Build plugins
2. חפשו "Flutter" והתקינו את `netlify-plugin-flutter`

#### אופציה חלופית: Build Image מותאם אישית

ב-`netlify.toml`, הוסיפו:

```toml
[build.environment]
  FLUTTER_VERSION = "3.24.0"  # גרסת Flutter
```

### 4. משתני סביבה (Environment Variables)

אם יש לכם API keys או סודות:
1. Site settings → Build & deploy → Environment variables
2. הוסיפו את המשתנים הנדרשים (למשל Firebase config)

### 5. התאמות אישיות

#### שינוי שם האתר
- Site settings → General → Site details → Change site name

#### דומיין מותאם אישית
- Site settings → Domain management → Add custom domain

#### HTTPS
- Netlify מספקת HTTPS אוטומטית עם Let's Encrypt

### 6. בדיקת הפריסה

לאחר הפריסה, בדקו:
- ✅ האתר נטען בהצלחה
- ✅ הניווט בין דפים עובד
- ✅ הסאונד מתנגן
- ✅ האתר מגיב במובייל

## פתרון בעיות נפוצות

### בעיה: "Command not found: flutter"
**פתרון**: וודאו שהתקנתם את `netlify-plugin-flutter`

### בעיה: "Failed to load asset"
**פתרון**: וודאו ש-`--web-renderer canvaskit` משמש בבנייה

### בעיה: "404 on refresh"
**פתרון**: וודאו שקובץ `_redirects` קיים ב-`build/web`

### בעיה: פונטים בעברית לא נטענים
**פתרון**: וודאו שהפונטים מוגדרים ב-`pubspec.yaml` ונכללים ב-assets

## עדכונים עתידיים

כל פעם שתעשו push לריפוזיטורי:
1. Netlify יזהה את השינוי אוטומטית
2. יבנה את הפרויקט מחדש
3. יפרוס את הגרסה החדשה

## קישורים שימושיים

- Netlify Docs: https://docs.netlify.com
- Flutter Web Deployment: https://docs.flutter.dev/deployment/web
- Netlify Flutter Plugin: https://github.com/netlify/netlify-plugin-flutter

---

**נוצר עבור פרויקט "ניחוש שירים"** 🎵
