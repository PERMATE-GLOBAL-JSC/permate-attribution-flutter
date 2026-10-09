import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'permate_attribution_api.g.dart';

export 'models.dart';
export 'predefined_event.dart';

/// Permate Attribution SDK for Flutter (wraps native Android + iOS SDK).
class PermateAttribution {
  PermateAttribution._();

  static const String sdkVersion = '3.2.1';

  static PermateAttributionHostApi _api = PermateAttributionHostApi();
  static bool _flutterApiReady = false;

  static void Function(AttributionResult result)? onAttributionSuccess;
  static void Function(AttributionError error)? onAttributionFailure;
  static void Function(DeepLinkResult result)? onDeepLinkResolved;

  /// Test-only hook to inject a mock [PermateAttributionHostApi].
  static set hostApi(PermateAttributionHostApi api) => _api = api;

  static void _ensureFlutterApi() {
    if (_flutterApiReady) return;
    PermateAttributionFlutterApi.setUp(_FlutterApiHandler());
    _flutterApiReady = true;
  }

  /// Test-only: clear FlutterApi registration.
  @visibleForTesting
  static void resetFlutterApiForTest() {
    PermateAttributionFlutterApi.setUp(null);
    _flutterApiReady = false;
  }

  static Future<void> configure({
    required String appKey,
    AttributionOptions options = const AttributionOptions(),
  }) async {
    _ensureFlutterApi();
    await _api.configure(
      appKey,
      AttributionOptionsDto(
        environment: options.environment.name,
        baseUrl: options.baseUrl,
        logLevel: options.logLevel.name,
        sessionEnabled: options.sessionEnabled,
        minTimeBetweenSessionsMs: options.minTimeBetweenSessions.inMilliseconds,
        disableAdvertisingIdentifier: options.disableAdvertisingIdentifier,
        disableIDFVCollection: options.disableIDFVCollection,
      ),
    );
  }

  /// Idempotent. Loads remote config and schedules install resolve when active.
  /// Call after [configure]. Does not run implicitly from [logEvent] / [handleDeepLink].
  static Future<void> start() => _api.start();

  static Future<AttributionResult?> getAttribution() async {
    final dto = await _api.getAttribution();
    return dto == null ? null : _mapAttributionResult(dto);
  }

  static Future<DeepLinkResult?> handleDeepLink(String url) async {
    _ensureFlutterApi();
    final dto = await _api.handleDeepLink(url);
    if (dto == null) return null;
    return _mapDeepLinkResult(dto);
  }

  /// Extract deep link from FCM/APNs-style payload (`pm_dl` / `deep_link` / `url`).
  static Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    _ensureFlutterApi();
    final pigeonPayload = <String?, Object?>{};
    for (final entry in payload.entries) {
      pigeonPayload[entry.key] = entry.value;
    }
    return _api.handlePushNotification(pigeonPayload);
  }

  static Future<void> logEvent(
    String name, [
    Map<String, Object?>? params,
  ]) async {
    final sanitized = _sanitizeEventParams(params);
    await _api.logEvent(name, sanitized);
  }

  /// Staging / QA only — no-op in production on native SDKs.
  static Future<void> reset() => _api.reset();

  /// Android: forward FCM token for server-side uninstall probing (`POST /push-token`).
  /// Blank / oversized / unconfigured → soft no-op on native. iOS Flutter plugin: no-op.
  /// Call on cold start and on token refresh. Does not emit an `uninstall` event.
  static Future<void> updatePushToken(String token) => _api.updatePushToken(token);

  /// Force-refreshes remote config (bypasses TTL). Recovery path when kill-switch engaged.
  static Future<RemoteConfigSnapshot> refreshConfig() async {
    try {
      final dto = await _api.refreshConfig();
      return _mapRemoteConfigSnapshot(dto);
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  /// Host-app kill switch (native persist). Call after [configure].
  ///
  /// When `true`, native SDK blocks resolve / event flush / config refresh and clears
  /// the event queue. Independent of server `is_active`. Before configure: returns
  /// `false` / set is a no-op on native.
  static Future<bool> getIsDeactivated() => _api.getIsDeactivated();

  /// See [getIsDeactivated].
  static Future<void> setIsDeactivated(bool value) =>
      _api.setIsDeactivated(value);

  /// iOS REQ-SDK-017: when true, native does not read/send IDFA.
  /// Android: always `false` / set is a no-op.
  static Future<bool> getDisableAdvertisingIdentifier() =>
      _api.getDisableAdvertisingIdentifier();

  /// See [getDisableAdvertisingIdentifier].
  static Future<void> setDisableAdvertisingIdentifier(bool value) =>
      _api.setDisableAdvertisingIdentifier(value);

  /// iOS REQ-SDK-017: when true, new `device_id` is random UUID (not IDFV).
  /// Apply before first [start]. Android: always `false` / set is a no-op.
  static Future<bool> getDisableIDFVCollection() =>
      _api.getDisableIDFVCollection();

  /// See [getDisableIDFVCollection].
  static Future<void> setDisableIDFVCollection(bool value) =>
      _api.setDisableIDFVCollection(value);

  /// Last-known IDFA string, or empty when disabled / denied / on Android.
  static Future<String> getAdvertisingIdentifier() =>
      _api.getAdvertisingIdentifier();

  /// iOS 14+: defer resolve/IDFA until ATT status ≠ `notDetermined`, or [timeout].
  /// Does **not** show the ATT dialog — Brand must call
  /// `ATTrackingManager.requestTrackingAuthorization`. Android: no-op.
  /// Safe before [configure]. Prefer calling before [start].
  static Future<void> waitForATTUserAuthorization(Duration timeout) =>
      _api.waitForATTUserAuthorization(timeout.inMilliseconds / 1000.0);

  static Future<String> nativeSdkVersion() => _api.getSdkVersion();

  static AttributionResult _mapAttributionResult(AttributionResultDto dto) {
    return AttributionResult(
      attributed: dto.attributed,
      clickId: dto.clickId,
      campaignId: dto.campaignId,
      offerId: dto.offerId,
      partnerId: dto.partnerId,
      resolvedAt: dto.resolvedAt,
      channel: dto.channel,
      isActive: dto.isActive,
      deferredParams: _stringMap(dto.deferredParams),
    );
  }

  static DeepLinkResult _mapDeepLinkResult(DeepLinkResultDto dto) {
    final raw = _stringMap(dto.rawParams) ?? const <String, String>{};
    final offerId = dto.offerId ??
        int.tryParse(raw['pm_offer_id'] ?? '') ??
        int.tryParse(raw['offer_id'] ?? '');
    return DeepLinkResult(
      campaignId: dto.campaignId,
      clickId: dto.clickId,
      offerId: offerId,
      isDeferred: dto.isDeferred,
      rawParams: raw,
    );
  }

  static Map<String, String>? _stringMap(Map<String?, String?>? raw) {
    if (raw == null) return null;
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key != null && value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  static RemoteConfigSnapshot _mapRemoteConfigSnapshot(
    RemoteConfigSnapshotDto dto,
  ) {
    return RemoteConfigSnapshot(
      isActive: dto.isActive,
      cacheTtlSec: dto.cacheTtlSec,
      fetchedAtMillis: dto.fetchedAtMillis,
    );
  }

  static PermateAttributionException _mapPlatformException(
    PlatformException e,
  ) {
    return PermateAttributionException(
      e.message ?? e.toString(),
      code: e.code,
    );
  }

  static Map<String?, Object?>? _sanitizeEventParams(
    Map<String, Object?>? params,
  ) {
    if (params == null) return null;
    final out = <String?, Object?>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null ||
          value is String ||
          value is num ||
          value is bool) {
        out[entry.key] = value;
      }
    }
    return out;
  }
}

class _FlutterApiHandler implements PermateAttributionFlutterApi {
  @override
  void onAttributionSuccess(AttributionResultDto result) {
    PermateAttribution.onAttributionSuccess?.call(
      PermateAttribution._mapAttributionResult(result),
    );
  }

  @override
  void onAttributionFailure(String code, String message) {
    PermateAttribution.onAttributionFailure?.call(
      AttributionError(code: code, message: message),
    );
  }

  @override
  void didResolveDeepLink(DeepLinkResultDto result) {
    PermateAttribution.onDeepLinkResolved?.call(
      PermateAttribution._mapDeepLinkResult(result),
    );
  }
}
