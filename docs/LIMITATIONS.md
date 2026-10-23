# Known limitations

## Video-counting accuracy

ScrollLess has no API access to Instagram or YouTube. It infers "a new video
is on screen" from the accessibility tree, so counting is heuristic. The
design errs toward **not double-counting** rather than catching every edge
case; the typical failure mode is an occasional missed video, not an
inflated count.

What is counted:

* A page of the Reels/Shorts pager that stays on screen for at least the
  *minimum watch time* (default 2 s; 1 / 2 / 3 / 5 s in Settings → "Count a
  video after") and whose visible words (creator handle, caption, audio
  title) differ from the page before it (overlap coefficient below 0.6)
  **or** whose pager index changed.

What is deliberately *not* counted:

* Pages that fly past during a fast fling or a quick swipe-past (never on
  screen for the minimum watch time). A video the user flicks away after
  1.9 s with the default setting is therefore *not* counted; raise or lower
  the threshold in Settings to taste.
* The same video seen again after scrolling back (fingerprint ≥ 0.85 similar
  to one of the last 60 counted videos at the same pager index).
* Content drift on the same page: "…more" caption expansion, like/comment
  counters ticking, progress bars, timestamps.
* Anything while the viewer is not full screen (home feed, Shorts shelf in
  the YouTube home tab, Explore grid, profile grids).

Where it can be wrong:

| Situation | Effect | Why |
| --- | --- | --- |
| Two consecutive videos with (almost) identical visible text and no pager index (e.g. same creator, no caption, Instagram when `CollectionItemInfo` is absent) | missed count | The fingerprints are ≥ 0.6 similar and there is no index to disambiguate. |
| A video with no readable text at all (no caption, hidden handle) | missed count | Empty fingerprint is ignored to avoid phantom counts. |
| Instagram/YouTube rename their view ids | counts continue with `MEDIUM` confidence via layout heuristics; if the heuristic also fails, counting stops until the id lists are updated | Both apps change ids between releases. Detections carry a `confidence` so you can see which path fired. |
| Re-watching a video that fell out of the 60-entry history | counted again | Bounded memory. |
| Autoplay to the next video without a swipe | counted (correctly) | The page changes, so this is a transition. |
| Ads inside the Reels/Shorts pager | counted as a video | They are pages in the same pager; there is no reliable, language-independent "Sponsored" marker. |
| Picture-in-picture / split screen | untested | The classifier assumes the pager fills ≥ 60% of the screen height. |
| Non-Latin or emoji-only captions | works, but similarity is coarser | Tokens are whitespace/punctuation separated words of ≥ 3 characters; scripts without spaces produce fewer tokens. |

## Validation performed

* 31 JVM unit tests over the detector, fingerprinting, surface classifier and
  usage tracker: first stable page, genuine transitions, fast fling, caption
  expansion, scroll-back duplicates, pager-index override, surface exit and
  re-entry, per-package isolation, rate limit, restart adoption, and
  regression trees captured from the real YouTube app (Home tab must not
  count; Shorts player must).
* 13 Flutter tests (models, SQLite repository against the real schema via
  `sqflite_common_ffi`, dashboard widget behaviour).
* Live test on a Pixel 7 emulator (Android 17, YouTube 21.41, release APK),
  driven over adb with the service enabled:

  | Action | Count after | Expected |
  | --- | --- | --- |
  | Open YouTube, sit on Home, scroll the feed | 0 | 0 |
  | Tap the Shorts tab (first Short loads) | 1 | 1 |
  | Swipe up ×4 | 5 | 5 |
  | Swipe down (back to previous Short) | 5 | 5 |
  | Swipe up (Short already counted) | 5 | 5 |
  | Swipe up (new Short) | 6 | 6 |
  | Tap Home tab, then device Home | 6 | 6 |

  All six detections were `HIGH` confidence (`reel_recycler` found). The
  floating pill showed the running count and time over Shorts and the
  dashboard reflected the same numbers.
* 1.2.0 on the same emulator: the in-app "Add widget" button opened the
  launcher's "Add to home screen" sheet (with the widget's live preview),
  the app detected the pinned widget, the widget showed the running count,
  per-app split, time and goal bar after a Shorts session, and the overlay
  showed `21 Shorts · 21/30 · 1m` with the goal-aware status dot.

## Home-screen widget

* Two sizes are offered in the launcher's widget picker and from the app's
  Setup screen: small (2×2) and large (4×3). Every instance is resizable and
  switches between the small, medium and large layouts as it grows
  (Android 12+ picks the layout per size; older versions use the widget's
  current cell size).
* Pinning from inside the app needs a launcher that supports
  `requestPinAppWidget` (Pixel Launcher, most OEM launchers on Android 8+).
  Otherwise the app explains how to add it manually.
* The widget refreshes after every counted video and once a minute while a
  tracked app is open; otherwise the launcher refreshes it every 30 minutes,
  so after midnight it can show yesterday's numbers for up to half an hour
  until the app, the service or the launcher updates it.
* Instagram could not be exercised live (the emulator has no signed-in
  Instagram account). Its id list (`clips_viewer_view_pager`,
  `clips_video_container`, …) comes from public accessibility dumps of the
  current Instagram app; the heuristic fallback covers id drift. **Treat
  Instagram counting as untested until it has been checked on a real
  device.**

Two bugs were found and fixed *by* the live test and are worth knowing about:

1. The original heuristic accepted YouTube's Home tab (a full-screen
   `ScrollView` plus a stray `reel_time_bar` view). Markers must now be
   inside a `RecyclerView`/`ViewPager` candidate and the innermost one wins.
2. When the accessibility service restarts while a video is on screen, that
   video was counted again. The service now adopts the on-screen page
   without counting if a count for that app happened in the previous 90 s.
3. (1.1.0) A YouTube picture-in-picture window kept emitting events after the
   user left YouTube, so the overlay and "YouTube is open" banner re-appeared
   over other apps and PiP time was billed as foreground time. Events from a
   tracked app are now ignored unless its window is the active window.

## Time tracking

* "Scrolling time" is the time the Reels/Shorts viewer was on screen while
  the app was in the foreground. "In app" is total foreground time.
* Time is only accumulated while the service receives events or its 1-second
  tick runs; gaps longer than 15 s are discarded (screen off, device asleep).
* A video playing with the screen on but no interaction still counts as
  time, which is intended.
* Days roll over at local midnight; a session spanning midnight is attributed
  to the day when each second elapsed.

## Platform constraints

* The accessibility service must be enabled manually by the user; Android
  does not allow apps to enable it themselves, and some OEMs (Xiaomi, Oppo,
  Vivo…) disable accessibility services after reboot or aggressive battery
  optimisation. Re-enable it if counting stops.
* No `android:packageNames` filter is set on the service so that leaving
  Instagram/YouTube can be detected. The service receives *package names* of
  other apps' window-state changes but never reads their content.
* Android may warn that the service "can read screen content"; that is
  inherent to how ScrollLess works.
* Overlay uses `TYPE_ACCESSIBILITY_OVERLAY`, so it disappears whenever the
  service is disabled and cannot be shown over the lock screen.
* Instagram Lite, YouTube Go, browser versions and other third-party clients
  are not tracked.
* Minimum Android version is 8.0 (API 26).

## Crash reporting

* Firebase Crashlytics receives stack traces for native and Dart crashes in
  release builds only. It is disabled in debug builds.
* Crashlytics uploads on the *next* launch after a crash. Reports typically
  appear in the console within a few minutes.
* Verified on 2026-10-22: a deliberate `RuntimeException: ScrollLess test
  crash (intentional)` from release build 1.0.0 on the emulator was captured
  by the SDK, uploaded on relaunch, and listed as a fatal issue in the
  Firebase console (also confirmed through the Crashlytics API: issue
  `7f5e330e45c17b3f173c1c44386dfe00`, 2 events). The same test on 1.1.0 (3)
  was received by Crashlytics ten seconds after the crash (API event
  `2277959058875416001`, version display name "1.1.0 (3)"). The in-app test-crash button was
  removed from the store build (1.1.0 (4)) at the owner's request; future
  verification needs a debug build or a real crash.
