enum Environment { staging, production }

enum LogLevel { error, verbose }

class AttributionOptions {
  const AttributionOptions({
    this.environment = Environment.production,
    this.baseUrl,
    this.logLevel = LogLevel.error,
    this.sessionEnabled = true,
    this.minTimeBetweenSessions = const Duration(minutes: 30),
    this.disableAdvertisingIdentifier = false,
    this.disableIDFVCollection = false,
  });

  final Environment environment;
  final String? baseUrl;
  final LogLevel logLevel;

  /// When true, native SDK may emit `session_start` on session boundaries. Default true.
  final bool sessionEnabled;

  /// Minimum time between sessions. Default 30 minutes (matches Android / iOS).
  final Duration minTimeBetweenSessions;

  /// iOS REQ-SDK-017: when true, do not read/send IDFA. Android: ignored.
  final bool disableAdvertisingIdentifier;

  /// iOS REQ-SDK-017: when true, new `device_id` is random UUID (not IDFV) and omit wire `idfv`.
  /// Apply before first [PermateAttribution.start]. Android: ignored.
  final bool disableIDFVCollection;
}

class AttributionResult {
  const AttributionResult({
    required this.attributed,
    this.clickId,
    this.campaignId,
    this.offerId,
    this.partnerId,
    this.resolvedAt,
    this.channel,
    this.isActive,
    this.deferredParams,
  });

  final bool attributed;
  final String? clickId;
  final String? campaignId;
  final int? offerId;
  final int? partnerId;
  final String? resolvedAt;
  final String? channel;

  /// Server kill-switch from `/resolve`. `null` or `true` → SDK keeps operating.
  final bool? isActive;

  /// Extra params from the marketing link on first-open `/resolve`.
  final Map<String, String>? deferredParams;
}

class DeepLinkResult {
  const DeepLinkResult({
    this.campaignId,
    this.clickId,
    this.offerId,
    this.isDeferred = false,
    this.rawParams = const {},
  });

  /// Present when the link includes `pm_cid`; null for click-only deep links.
  final String? campaignId;
  final String? clickId;

  /// From `pm_offer_id` / `offer_id` when present (or native Android getter).
  final int? offerId;

  /// `true` for deferred UDL after first-open resolve; `false` for direct links.
  final bool isDeferred;

  final Map<String, String> rawParams;
}

/// Typed attribution failure (native [AttributionError] parity).
class AttributionError implements Exception {
  const AttributionError({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// Stable codes: `invalid_app_key`, `brand_disabled`, `http`, `network_failure`, `unknown`.
  final String code;
  final String message;
  final int? statusCode;

  bool get isInvalidAppKey => code == 'invalid_app_key';
  bool get isBrandDisabled => code == 'brand_disabled';

  @override
  String toString() => 'AttributionError($code): $message';
}

/// Snapshot of remote SDK config (`GET /api/v1/sdk/config`).
class RemoteConfigSnapshot {
  const RemoteConfigSnapshot({
    required this.isActive,
    this.cacheTtlSec,
    this.fetchedAtMillis,
  });

  final bool isActive;
  final int? cacheTtlSec;
  final int? fetchedAtMillis;
}

class PermateAttributionException implements Exception {
  const PermateAttributionException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'PermateAttributionException($code): $message';
}
