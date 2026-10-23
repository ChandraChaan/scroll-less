# ScrollLess – Play Store publish checklist

Version **1.2.0 (versionCode 5)** · package `dev.chandra.scroll_less` · built 2026-10-22

## 1. Artifacts (all under `store/`)

| What | Path | Status |
| --- | --- | --- |
| Signed release AAB (upload this to Play) | `store/release/scrollless-1.2.0-5-release.aab` | built, `jarsigner -verify` OK |
| Signed release APK (testers / sideload) | `store/release/scrollless-1.2.0-5-release.apk` | built, `apksigner verify` OK (v2) |
| Checksums | `store/release/SHA256SUMS.txt` | |
| Play Store icon 512×512 (no alpha) | `store/graphics/play_store_icon_512.png` | |
| Feature graphic 1024×500 | `store/graphics/feature_graphic.png` | |
| Phone screenshots 1080×2400 (8) | `store/screenshots/phone/01_today.png` … `08_dark_mode.png` | captured from the release build on a Pixel 7 emulator, framed |
| Raw unframed screenshots | `store/screenshots/raw/` | |
| Tablet screenshots | not produced | optional for phones-only apps; see §6 |
| Brand sources (SVG + PNG) | `assets/brand/` | |
| Store text | `store/listing/listing.md` | title, short/full description, release notes |
| Data safety answers | `store/listing/data_safety.md` | |
| Content rating answers | `store/listing/content_rating.md` | |
| Accessibility API + permissions declaration | `store/listing/permissions_declaration.md` | |
| Privacy policy (hosted) | https://scroll-less-chandra.web.app/privacy (source: `store/hosting/privacy.html`) | live, HTTP 200 |

Signing: `android/keystore/scrollless-release.jks` (alias `scrollless`, RSA-4096,
SHA-256 `BE8F…34E8`), passwords in `android/key.properties`. Both are git-ignored.
**Back them up now** – Play App Signing will wrap this key, but you still need it to
upload every future release.

## 2. Verification performed on this build

| Check | Result |
| --- | --- |
| `flutter analyze` | no issues |
| Flutter tests (`flutter test`) | 17 pass |
| Kotlin JVM tests (`:app:testDebugUnitTest`) | 31 pass |
| APK signature (`apksigner verify --print-certs`) | verifies, CN=ScrollLess, SHA-256 be8fc89e…34e8 |
| AAB signature (`jarsigner -verify`) | jar verified, same certificate |
| Manifest | versionCode 5, versionName 1.2.0, minSdk 26, targetSdk 36; permissions: INTERNET, ACCESS_NETWORK_STATE only (widgets need no permission) |
| Live run on Pixel 7 emulator (Android 17, YouTube 21.41) | Shorts counted once per video with HIGH confidence; no counts on the Home tab; quick swipe-past not counted (2 s minimum watch time); overlay shows/hides correctly; picture-in-picture handled; small and large widgets pinned from the app and updating |
| Onboarding → disclosure → Accessibility settings | works; disclosure must be accepted before settings open |
| Crashlytics | Test crashes from 1.0.0 (2) and 1.1.0 (3) both received and grouped under issue `7f5e330e45c17b3f173c1c44386dfe00` (confirmed through the Crashlytics API). The test-crash button was removed in 1.1.0 (4); 1.2.0 ships the same Crashlytics wiring. |

## 3. Things only you can do (manual)

1. **Instagram Reels on a real phone.** The emulator has no Instagram account, so
   Reels counting is untested. Install the APK from App Distribution on your phone,
   enable the service, open Reels and confirm the floating pill increments once per
   Reel. If it does not, run `adb shell uiautomator dump` while on Reels and send the
   `resource-id`s containing `clips`; the id lists in `SurfaceClassifier.kt` can be
   updated in minutes.
2. **Developer account items**: contact email, developer name/address shown on the
   listing, and the D-U-N-S / identity verification Play requires for new accounts.
3. **Play App Signing** enrolment on first upload (recommended: let Play manage the
   app signing key; your keystore becomes the upload key).
4. **Accessibility API declaration form** (see `permissions_declaration.md`): a short
   screen recording of enabling the service and watching the counter helps the review.
5. Closed-testing requirement for new personal developer accounts: Play requires a
   closed test with at least 12 testers for 14 days before production access. Use the
   App Distribution testers list as the starting group.

## 4. Steps in Google Play Console

1. **Create app** → name "ScrollLess: Reels & Shorts", default language en-US, App,
   Free. Accept the declarations.
2. **Set up your app** (Dashboard tasks):
   - Privacy policy → `https://scroll-less-chandra.web.app/privacy`
   - App access → "All functionality is available without special access"
   - Ads → No
   - Content rating → answers in `content_rating.md`
   - Target audience → 18+ (or 13+), not designed for children
   - News app → No · COVID-19 → No · Data safety → `data_safety.md`
   - Government app → No · Financial features → None · Health → not a health app
   - App category → Tools; contact details; store listing (see `listing.md`)
3. **Main store listing**: paste title, short and full description; upload
   `play_store_icon_512.png`, `feature_graphic.png`, and the six phone screenshots.
4. **App content → Sensitive permissions / AccessibilityService API**: fill the
   declaration with the text from `permissions_declaration.md`.
5. **Testing → Internal testing → Create release**: upload
   `scrollless-1.2.0-5-release.aab`, paste release notes, save, review, roll out.
   Install from the internal-testing link on a real phone and do the Instagram check.
6. **Closed testing** (required for new personal accounts): promote the same build,
   add testers, run for 14 days, then apply for production access.
7. **Production → Create release**: promote the tested build, choose countries,
   review and roll out. Expect the Accessibility declaration to add review time.

## 5. After publishing

- Watch Crashlytics (`scroll-less-chandra` project) for the first days.
- Instagram/YouTube updates can change view ids; detections then fall back to
  `MEDIUM` confidence or stop. Keep `SurfaceClassifier.kt` id lists current and ship
  a patch release when needed.

## 6. Tablet screenshots (optional)

Play only requires tablet screenshots if you want the listing optimised for tablets.
The app is phone-first. If you want them: boot the `Medium_Tablet` emulator, install
the APK, capture with `adb exec-out screencap -p`, and frame with
`store/tools/make_screens.sh` (adjust the frame size in `frame.html`).
