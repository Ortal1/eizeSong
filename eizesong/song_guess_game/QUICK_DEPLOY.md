# פריסה מהירה ל-Netlify (ללא Git)

## הדרך הכי מהירה לפרסם את האפליקציה! 🚀

### שלב 1: בנייה מקומית
הקוד כבר נבנה! התיקייה `build/web` מוכנה להעלאה.

אם תרצו לבנות מחדש:
```bash
flutter build web --release
cp web/_redirects build/web/_redirects
```

### שלב 2: העלאה ל-Netlify

**אופציה א': גרירה ישירה (הכי פשוט!)**

1. היכנסו ל-https://app.netlify.com
2. גררו את התיקייה **`build/web`** (כל התיקייה!) ישירות לחלון הדפדפן
3. זהו! האתר שלכם חי באוויר תוך שניות! 🎉

**אופציה ב': Netlify CLI**

```bash
# התקינו את Netlify CLI (פעם אחת)
npm install -g netlify-cli

# התחברו
netlify login

# פרסו
netlify deploy --prod --dir=build/web
```

### הבעיה שנתקלת בה:

ה-build ב-Netlify נכשל כי Netlify צריך להתקין Flutter, מה שלא קורה אוטומטית.

**פתרונות:**

1. **פריסה ידנית** (הדרך שלמעלה) - הכי מהיר!
2. **התקנת Plugin** - עדכנו את `netlify.toml` עם הפלאגין
3. **Push את העדכון ל-GitHub** - Netlify יתקין את הפלאגין אוטומטית

### לאחר פריסה ידנית:

האתר יהיה זמין ב:
```
https://wonderful-bublanina-59c1f1.netlify.app
```

תוכלו לשנות את השם באתר Netlify:
- Site settings → General → Site details → Change site name

---

**המלצה:** השתמשו בפריסה ידנית עכשיו כדי לראות את האתר חי,
ואחר כך אפשר להגדיר את ה-Git integration לעדכונים אוטומטיים.
