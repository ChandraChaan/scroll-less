# ScrollLess

ScrollLess is an Android app (Flutter UI + native Kotlin) that counts every
Instagram Reel and YouTube Short you watch, tracks how long you spend
scrolling in each app, and shows a live floating counter over Instagram and
YouTube. Everything is stored in a local SQLite database on the phone.

## How it works

| Layer | What it does |
| --- | --- |
| `ScrollLessAccessibilityService` (Kotlin) | Receives window events for Instagram and YouTube, classifies whether the full-screen Reels/Shorts viewer is showing, fingerprints the page under the screen centre and feeds it to the detector. Also times foreground / Reels-surface usage per app. |
| `SurfaceClassifier` | Finds the vertical pager by known view ids (`clips_viewer_*`, `reel_recycler`) and falls back to layout heuristics (near-full-screen scrollable with Reels/Shorts markers) when ids change. |
| `FingerprintBuilder` + `ReelDetector` | Turns the visible words of a page (creator, caption, audio) into a token set, ignores counters/timestamps/UI chrome, and counts a video only when a *new* page has been stable on screen for 400 ms, is not similar to the current one, and has not been counted recently. See [docs/LIMITATIONS.md](docs/LIMITATIONS.md). |
| `UsageTracker` | Attributes elapsed time to the active app and to the Reels/Shorts surface; discards gaps when the service was not observing. |
| `OverlayController` | Draggable floating pill (`TYPE_ACCESSIBILITY_OVERLAY`, so no "draw over other apps" permission) showing today's count and time for the app you are in. Tap opens ScrollLess. |
| `StatsDatabase` (Kotlin) / `SqliteStatsRepository` (Dart) | One SQLite file, `scrollless.db`: `daily_stats(day, package, reels, surface_ms, foreground_ms)` and `reel_events(ts, day, package, fingerprint, confidence)`. Kotlin writes, Flutter reads through `sqflite`; live updates reach Flutter over an `EventChannel`. |
| Flutter app | Onboarding with the Play-required Accessibility disclosure, three tabs (Today, History with 7/30-day charts, Settings), live banner, per-app cards, recent detections with confidence, overlay toggle, reset / delete, in-app privacy policy, light and dark themes. |

## Privacy

* Only the Instagram and YouTube windows are read. Other apps are used solely
  to notice that you left Instagram/YouTube (their content is never
  inspected).
* Counts, times and detections live in a local SQLite database. No account,
  no sync, no analytics, no ads.
* Each detection stores a 16-character hash of the on-screen words, never the
  words themselves.
* The only network traffic is Firebase Crashlytics (stack traces of crashes),
  which is disabled in debug builds.

## Build

Requirements: Flutter 3.44+, JDK 17, Android SDK 36.

```bash
flutter pub get
flutter analyze
flutter test                                # Dart unit + widget tests
(cd android && ./gradlew :app:testDebugUnitTest)   # Kotlin detector tests
flutter build apk --release
```

### Release signing

`android/app/build.gradle.kts` reads `android/key.properties` (git-ignored):

```
storeFile=keystore/scrollless-release.jks
storePassword=…
keyAlias=scrollless
keyPassword=…        # must equal storePassword for PKCS12 keystores
```

Without that file release builds fall back to the debug key so the project
still compiles on other machines. Never commit the keystore or the
properties file; both are covered by `.gitignore`.

### Firebase

Project `scroll-less-chandra`, Android app `dev.chandra.scroll_less`.
`lib/firebase_options.dart` and `android/app/google-services.json` are
Firebase *client* configuration (identifiers, not credentials) and are
committed so the project builds from a clean clone. Crashlytics is wired via
the `com.google.firebase.crashlytics` Gradle plugin (mapping files are
uploaded on release builds) and `firebase_crashlytics` in Dart.

Distribute a build to testers:

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:687567897909:android:514ba8205b2dfcb911f87c \
  --groups testers --release-notes "…"
```

## Using the app

1. Install, open ScrollLess, tap **Open accessibility settings**, enable
   *ScrollLess* under Installed / Downloaded apps.
2. Open Instagram Reels or YouTube Shorts. The floating pill shows today's
   count and scrolling time for that app; the dashboard updates live.
3. Toggle the floating counter, reset today or delete all data from
   *Settings* in the app.

## Play Store release

Everything needed for the listing lives under `store/`: signed AAB/APK and
checksums (`store/release/`, git-ignored binaries), icon and feature graphic
(`store/graphics/`), framed phone screenshots (`store/screenshots/phone/`),
listing text and policy answers (`store/listing/`), the hosted privacy policy
source (`store/hosting/`, deployed to https://scroll-less-chandra.web.app/privacy)
and the step-by-step [publish checklist](store/PUBLISH_CHECKLIST.md).
Brand sources are in `assets/brand/`; launcher icons and the Android 12 splash
are generated with `flutter_launcher_icons` and `flutter_native_splash`
(configuration in `pubspec.yaml`).

## Test status

| Suite | Count | Result |
| --- | --- | --- |
| Kotlin JVM unit tests (`:app:testDebugUnitTest`) | 31 | pass |
| Flutter unit + widget tests (`flutter test`) | 15 | pass |
| `flutter analyze` | – | no issues |
| Live YouTube Shorts run on a Pixel 7 emulator (release APK) | 7 scenarios | pass, see docs/LIMITATIONS.md |
| Crashlytics end-to-end (test crash → issue) | 2 builds | 1.0.0 and 1.1.0 (3) both confirmed via the Crashlytics API |

## Known limitations

See [docs/LIMITATIONS.md](docs/LIMITATIONS.md) for the honest list,
especially around video-counting accuracy.
