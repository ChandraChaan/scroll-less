# Permissions and policy declarations

## Manifest permissions in the AAB

| Permission | Why |
| --- | --- |
| `android.permission.INTERNET` | Firebase Crashlytics crash reports only |
| `android.permission.BIND_ACCESSIBILITY_SERVICE` (on the service, not a runtime permission) | Required by Android for any accessibility service |
| `android.permission.ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE` etc. | Pulled in by Firebase SDKs; no user-facing behaviour |

No runtime (dangerous) permissions are requested. The floating counter uses
`TYPE_ACCESSIBILITY_OVERLAY`, so `SYSTEM_ALERT_WINDOW` is **not** declared.

## Accessibility API declaration (required)

Play Console → Policy → App content → **Sensitive app permissions / Accessibility API**
(the form is called "AccessibilityService API" in the console). Google reviews this
manually; answer honestly and consistently with the in-app disclosure.

| Question | Answer |
| --- | --- |
| Is your app designed to help people with disabilities? | **No** |
| Is the AccessibilityService API core to your app's functionality? | **Yes** |
| Describe the core functionality | ScrollLess is a digital-wellbeing tool that counts how many Instagram Reels and YouTube Shorts the user watches and how long they spend scrolling, and shows a live counter. The AccessibilityService API is the only Android mechanism that lets the app detect when a new short video is displayed inside another app. The service observes window content only for `com.instagram.android` and `com.google.android.youtube`; for all other packages it only uses the package name of window-state events to stop its timers. It does not perform gestures or actions, does not take screenshots and does not read text input. |
| Why can't this be done with other APIs? | UsageStatsManager only exposes foreground time per app, not individual video transitions. Digital Wellbeing APIs are not available to third-party apps. There is no public API from Instagram or YouTube for this. |
| Does the app show a prominent disclosure before requesting the service? | **Yes** – an in-app dialog ("ScrollLess needs the Accessibility service") explains what is accessed, that other apps are ignored, and that data stays on the device; the user must tap "Agree & continue" before being sent to Accessibility settings. |
| Is user data collected through the API transmitted off-device? | **No** – on-screen text is processed in memory; only a 16-character hash per counted video is stored locally. |
| Video / screenshots demonstrating the use | Attach `store/screenshots/phone/*.png` and, ideally, a screen recording of enabling the service and watching the floating counter update. |

Policy references:
- https://support.google.com/googleplay/android-developer/answer/10964491 (AccessibilityService API policy)
- The `android:description` string shown in Android's Accessibility settings (already in `strings.xml`) repeats the same disclosure.

## Other App content declarations

| Declaration | Answer |
| --- | --- |
| Ads | No, the app does not contain ads |
| App access | All functionality is available without special access (no login) |
| Target audience | 18 and over (or 13+); not designed for children |
| News app | No |
| COVID-19 contact tracing / status | No |
| Data safety | see `data_safety.md` |
| Government app | No |
| Financial features | None |
| Health | Not a health app (digital wellbeing only; select "My app does not have any health features" unless the console insists – then "Other wellness") |
