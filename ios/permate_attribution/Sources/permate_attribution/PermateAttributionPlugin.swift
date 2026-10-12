import Flutter
// The source package module is PermateAttribution; the binary XCFramework module is PermateAttributionSDK.
#if canImport(PermateAttributionSDK)
import PermateAttributionSDK
#else
import PermateAttribution
#endif

/// One instance per FlutterEngine. The native SDK has a single (weak) delegate slot, so exactly
/// one attached instance (the "owner") receives callbacks. Ownership is handed over — never
/// cleared — while another engine is still attached. Lifecycle + Pigeon calls run on main.
public class PermateAttributionPlugin: NSObject, FlutterPlugin, PermateAttributionHostApi,
  PermateAttributionDelegate, PermateDeepLinkDelegate
{
  /// Attach order; strong refs keep the owner alive (native delegate is weak).
  private static var attached: [PermateAttributionPlugin] = []
  private static weak var owner: PermateAttributionPlugin?

  private var flutterApi: PermateAttributionFlutterApi?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PermateAttributionPlugin()
    instance.flutterApi = PermateAttributionFlutterApi(binaryMessenger: registrar.messenger())
    PermateAttributionHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    // Publishing makes the engine call detachFromEngine(for:) when it is destroyed.
    registrar.publish(instance)
    attached.append(instance)
    if owner == nil { instance.claimDelegates() }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    PermateAttributionHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    flutterApi = nil
    Self.attached.removeAll { $0 === self }
    if Self.owner === self {
      if let next = Self.attached.first {
        next.claimDelegates()
      } else {
        Self.owner = nil
        PermateAttribution.shared.delegate = nil
        PermateAttribution.shared.deepLinkDelegate = nil
      }
    }
  }

  private func claimDelegates() {
    Self.owner = self
    PermateAttribution.shared.delegate = self
    PermateAttribution.shared.deepLinkDelegate = self
  }

  func getSdkVersion() throws -> String {
    PermateAttribution.shared.sdkVersion
  }

  func configure(appKey: String, options: AttributionOptionsDto) throws {
    PermateAttribution.shared.configure(appKey: appKey, options: options.toNative())
    claimDelegates()
  }

  func start() throws {
    PermateAttribution.shared.start()
  }

  func getAttribution() throws -> AttributionResultDto? {
    PermateAttribution.shared.getAttribution()?.toDto()
  }

  func handleDeepLink(url: String) throws -> DeepLinkResultDto? {
    guard let parsed = URL(string: url) else { return nil }
    return PermateAttribution.shared.handleDeepLink(url: parsed)?.toDto()
  }

  func handlePushNotification(payload: [String?: Any?]) throws -> Bool {
    var cleaned: [AnyHashable: Any] = [:]
    for (key, value) in payload {
      guard let key, let value else { continue }
      cleaned[key] = value
    }
    return PermateAttribution.shared.handlePushNotification(cleaned)
  }

  func logEvent(name: String, params: [String?: Any?]?) throws {
    var nativeParams: [String: Any]? = nil
    if let params = params {
      var out: [String: Any] = [:]
      for (key, value) in params {
        if let key = key, let value = value {
          out[key] = value
        }
      }
      nativeParams = out.isEmpty ? nil : out
    }
    PermateAttribution.shared.logEvent(name: name, params: nativeParams)
  }

  func reset() throws {
    PermateAttribution.shared.reset()
  }

  func updatePushToken(token: String) throws {
    // No-op until iOS native ships updatePushToken.
  }

  func refreshConfig(completion: @escaping (Result<RemoteConfigSnapshotDto, Error>) -> Void) {
    PermateAttribution.shared.refreshConfig { result in
      switch result {
      case .success(let snapshot):
        completion(.success(snapshot.toDto()))
      case .failure(let error):
        completion(
          .failure(
            PigeonError(
              code: "refresh_config_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        )
      }
    }
  }

  func getIsDeactivated() throws -> Bool {
    PermateAttribution.shared.isDeactivated
  }

  func setIsDeactivated(value: Bool) throws {
    PermateAttribution.shared.isDeactivated = value
  }

  func getDisableAdvertisingIdentifier() throws -> Bool {
    PermateAttribution.shared.disableAdvertisingIdentifier
  }

  func setDisableAdvertisingIdentifier(value: Bool) throws {
    PermateAttribution.shared.disableAdvertisingIdentifier = value
  }

  func getDisableIDFVCollection() throws -> Bool {
    PermateAttribution.shared.disableIDFVCollection
  }

  func setDisableIDFVCollection(value: Bool) throws {
    PermateAttribution.shared.disableIDFVCollection = value
  }

  func getAdvertisingIdentifier() throws -> String {
    PermateAttribution.shared.advertisingIdentifier
  }

  func waitForATTUserAuthorization(timeoutSeconds: Double) throws {
    PermateAttribution.shared.waitForATTUserAuthorization(
      timeoutInterval: TimeInterval(timeoutSeconds)
    )
  }

  // MARK: - PermateAttributionDelegate

  public func onAttributionSuccess(_ result: AttributionResult) {
    flutterApi?.onAttributionSuccess(result: result.toDto()) { _ in }
  }

  public func onAttributionFailure(_ error: AttributionError) {
    let mapped = Self.mapAttributionFailure(error)
    flutterApi?.onAttributionFailure(code: mapped.code, message: mapped.message) { _ in }
  }

  // MARK: - PermateDeepLinkDelegate

  public func didResolveDeepLink(_ result: DeepLinkResult) {
    flutterApi?.didResolveDeepLink(result: result.toDto()) { _ in }
  }

  private static func mapAttributionFailure(_ error: AttributionError) -> (code: String, message: String) {
    let message = error.errorDescription ?? error.localizedDescription
    switch error {
    // Android surfaces HTTP 401 as InvalidAppKey; iOS delivers the first /resolve 401 as .http(401).
    case .invalidAppKey, .http(401, _):
      return ("invalid_app_key", message)
    case .brandDisabled:
      return ("brand_disabled", message)
    case .http:
      return ("http", message)
    case .networkFailure:
      return ("network_failure", message)
    case .notConfigured, .alreadyResolving, .decoding, .missingBundleId,
      .invalidEventName, .invalidEventParams, .invalidDeepLink:
      return ("unknown", message)
    @unknown default:
      return ("unknown", message)
    }
  }
}

private extension AttributionOptionsDto {
  func toNative() -> AttributionOptions {
    var options = AttributionOptions(
      environment: environment.lowercased() == "staging" ? .staging : .production,
      baseUrl: baseUrl,
      logLevel: logLevel.lowercased() == "verbose" ? .verbose : .error,
      sessionEnabled: sessionEnabled,
      disableAdvertisingIdentifier: disableAdvertisingIdentifier,
      disableIDFVCollection: disableIDFVCollection
    )
    if let ms = minTimeBetweenSessionsMs {
      options.minTimeBetweenSessions = TimeInterval(ms) / 1000.0
    }
    return options
  }
}

private extension AttributionResult {
  func toDto() -> AttributionResultDto {
    var deferred: [String?: String?]? = nil
    if let deferredParams {
      var mapped: [String?: String?] = [:]
      for (key, value) in deferredParams {
        mapped[key] = value
      }
      deferred = mapped
    }
    return AttributionResultDto(
      attributed: attributed,
      clickId: clickId,
      campaignId: campaignId,
      offerId: offerId,
      partnerId: partnerId,
      resolvedAt: resolvedAt,
      channel: channel,
      isActive: isActive,
      deferredParams: deferred
    )
  }
}

private extension DeepLinkResult {
  func toDto() -> DeepLinkResultDto {
    let offerFromParams =
      Int64(rawParams["pm_offer_id"] ?? "") ?? Int64(rawParams["offer_id"] ?? "")
    var mapped: [String?: String?] = [:]
    for (key, value) in rawParams {
      mapped[key] = value
    }
    return DeepLinkResultDto(
      campaignId: campaignId,
      clickId: clickId,
      offerId: offerFromParams,
      isDeferred: isDeferred,
      rawParams: mapped
    )
  }
}

private extension RemoteConfigSnapshot {
  func toDto() -> RemoteConfigSnapshotDto {
    RemoteConfigSnapshotDto(
      isActive: isActive,
      cacheTtlSec: cacheTtlSec.map { Int64($0) },
      fetchedAtMillis: fetchedAtMillis
    )
  }
}
