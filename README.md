# Lab Results Reader — Flutter app

Upload a photo or PDF of a lab report and get it explained in plain English.
Talks to the server at `https://labresultsreader.moezzadigital.com/api.php` (the Gemini key stays on the server).

## Download the APK
https://github.com/digitalnova0101/lab-results-reader-android/releases/latest/download/LabResultsReader.apk

Every push to `main` builds a new APK automatically (see the **Actions** tab).

## Where things are
- `lib/screens/home.dart` — upload, camera, PDF, loading steps
- `lib/screens/result.dart` — summary ring, range bars, follow-up chat
- `lib/screens/history.dart`, `lib/screens/profile.dart` — history and settings
- `lib/api.dart` — server address
- `lib/state.dart` — free report limit, saved data

The old WebView version is kept in the `webview` branch.
