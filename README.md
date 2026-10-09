# Permate Attribution — Flutter plugin

Flutter wrapper for the native Permate Attribution SDK (Android + iOS). Business logic, storage, and HTTP live in the native modules — this plugin exposes the same public API via Pigeon.

## Requirements

- Flutter 3.44 or later.
- iOS: Swift Package Manager only (`flutter config --enable-swift-package-manager`). CocoaPods is not supported.
- Android: `minSdk` 23.

The native Android and iOS SDKs are resolved as pinned binary dependencies; this package contains only the Dart API and the thin platform bridge.

## Add dependency

```yaml
dependencies:
  permate_attribution: ^3.2.1
```

## Quick start

```dart
import 'package:permate_attribution/permate_attribution.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PermateAttribution.onDeepLinkResolved = (result) {
    // DIRECT or DEFERRED (isDeferred)
    // result.rawParams for routing
  };
  PermateAttribution.onAttributionSuccess = (result) { /* ... */ };
  PermateAttribution.onAttributionFailure = (error) {
    // error.code: invalid_app_key | brand_disabled | http | network_failure | unknown
  };

  await PermateAttribution.configure(
    appKey: 'YOUR_STAGING_APP_KEY',
    options: const AttributionOptions(
      environment: Environment.staging,
      logLevel: LogLevel.verbose,
      // sessionEnabled defaults to true (emits session_start)
      minTimeBetweenSessions: Duration(minutes: 30),
    ),
  );
  await PermateAttribution.start();

  runApp(const MyApp());
}
```

Call `configure` + `start` before `logEvent` / `handleDeepLink`. Those APIs do **not** call `start()` implicitly.

`start()` is a **cold-start bootstrap once per process** (remote config + resolve when active). Later Brand calls are no-ops. Warm `session_start` (when `sessionEnabled`, default **true**) is driven by native lifecycle after background ≥ `minTimeBetweenSessions` — do not call `start()` again on every foreground. `minTimeBetweenSessions` only gates the session event, never skips resolve.

### Privacy / ATT (iOS — REQ-SDK-017)

Seed via `AttributionOptions` or mutate after configure. **Android methods are no-ops** (getters return `false` / `""`).

```dart
await PermateAttribution.configure(
  appKey: 'YOUR_KEY',
  options: const AttributionOptions(
    disableAdvertisingIdentifier: false,
    disableIDFVCollection: false,
  ),
);

// Brand owns the ATT dialog (Info.plist NSUserTrackingUsageDescription).
await PermateAttribution.waitForATTUserAuthorization(const Duration(seconds: 60));
// Then call ATTrackingManager.requestTrackingAuthorization from the host app,
// then start():
await PermateAttribution.start();

final idfa = await PermateAttribution.getAdvertisingIdentifier();
```

Runtime toggles: `get/setDisableAdvertisingIdentifier`, `get/setDisableIDFVCollection`.

### First open / attribution

`start()` auto-resolves on native when the SDK is active. Poll the cache and/or use `onAttributionSuccess`:

```dart
await PermateAttribution.start();
await Future<void>.delayed(const Duration(seconds: 2));
final result = await PermateAttribution.getAttribution();
// result?.attributed, clickId, campaignId, deferredParams, ...
```

Native `/resolve` includes `screen_width`, `screen_height`, and `screen_pixel_ratio` (Android + iOS `DeviceSignals`) and `is_first_launch`. **Android only:** also sends `is_from_link` (`true` only for direct `handleDeepLink` / Intent / push; `false` for cold start / deferred first-open). There is **no** Dart API for these wire fields — the Flutter plugin inherits them from the native modules (Flutter iOS will not send `is_from_link`). Screen metrics are **not** sent on `/event`.

### Remote config (kill-switch recovery)

```dart
try {
  final snapshot = await PermateAttribution.refreshConfig();
  // snapshot.isActive, cacheTtlSec, fetchedAtMillis
} on PermateAttributionException catch (e) {
  // not configured / native refresh failed
}
```

### Host kill switch (`isDeactivated`)

```dart
await PermateAttribution.setIsDeactivated(true);  // after configure
final stopped = await PermateAttribution.getIsDeactivated();
await PermateAttribution.setIsDeactivated(false); // resume (if server is_active still true)
```

Blocks native network (resolve / event flush / config refresh), clears the event queue, persists across relaunch. Independent of server `is_active`.

### Deep links / UDL

Use [`app_links`](https://pub.dev/packages/app_links) (or similar), then forward URLs:

```dart
final deepLink = await PermateAttribution.handleDeepLink(uri.toString());
// deepLink?.campaignId (nullable — click-only links are valid), clickId, isDeferred, rawParams, offerId
```

A deep link is accepted when it has `pm_cid` **or** a click id (`click_id` / `pm_click_id` / `click_uuid`).

Deferred UDL (first install) is delivered via `onDeepLinkResolved` with `isDeferred: true` (no Intent/URI). Direct links also notify the callback after native resolve.

### Push payloads

```dart
await PermateAttribution.handlePushNotification({
  'pm_dl': '<deep link containing pm_cid>', // or tracking /ql URL
});
```

Looks up `pm_dl` / `deep_link` / `url` (including nested `permate` / `custom`).

### Push token (Android uninstall probing)

Host app owns FCM (`firebase_messaging`). Forward the token on cold start and on refresh. Android native POSTs `/push-token` and dedupes by SHA-256 hash. iOS Flutter plugin is a no-op until native ships the API.

```dart
await PermateAttribution.updatePushToken(fcmToken);
```

Does not emit an `uninstall` event — detection is server-side (e.g. FCM `UNREGISTERED`).

### Events

```dart
await PermateAttribution.logEvent(
  PredefinedEvent.registrationComplete,
  {'step': '1'},
);
// Queue drains automatically (after enqueue, cold/warm start, network reconnect).
// There is no public flush() — same as native Android / iOS.
```

## API parity

| Dart | Native |
|------|--------|
| `configure` / `start` | ✓ (`sessionEnabled` default true, `minTimeBetweenSessions`) |
| `getAttribution` | ✓ (+ `deferredParams`) |
| `handleDeepLink` | ✓ (`isDeferred`, `rawParams`) |
| `handlePushNotification` | ✓ |
| `updatePushToken` | ✓ Android (`POST /push-token`); iOS Flutter plugin no-op |
| `onDeepLinkResolved` / attribution callbacks | ✓ FlutterApi |
| `logEvent` / `reset` | ✓ (no public `flush` — auto-flush only) |
| `refreshConfig` | ✓ |
| `getIsDeactivated` / `setIsDeactivated` | ✓ (host kill switch; native persist) |
| Privacy / ATT (REQ-SDK-017) | ✓ iOS; Android no-op stubs |
| `PredefinedEvent` | ✓ (finance niche + funnel) |
| `/resolve` `screen_*` | ✓ transparent via native (not a Dart API) |
| `/resolve` `is_from_link` | ✓ Android native only (not sent on iOS) |

Resolve is **internal** on native (triggered by `start()` / deep links) — not exposed on the Flutter surface.
