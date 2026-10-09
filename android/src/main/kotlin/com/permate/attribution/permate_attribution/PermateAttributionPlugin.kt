package com.permate.attribution.permate_attribution

import android.content.Context
import android.net.Uri
import com.permate.attribution.AttributionError
import com.permate.attribution.AttributionOptions
import com.permate.attribution.AttributionResult
import com.permate.attribution.DeepLinkResult
import com.permate.attribution.Environment
import com.permate.attribution.LogLevel
import com.permate.attribution.PermateAttribution
import com.permate.attribution.PermateAttributionDelegate
import com.permate.attribution.PermateDeepLinkDelegate
import com.permate.attribution.RemoteConfigSnapshot
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * One instance per FlutterEngine. The native SDK has a single delegate slot, so exactly one
 * attached instance (the "owner") receives callbacks. Engines bound to an Activity (UI) take
 * priority over headless engines (e.g. `firebase_messaging` background isolate), and ownership
 * is handed over — never cleared — while another engine is still attached.
 */
class PermateAttributionPlugin :
    FlutterPlugin,
    ActivityAware,
    PermateAttributionHostApi,
    PermateAttributionDelegate,
    PermateDeepLinkDelegate {
    private var applicationContext: Context? = null
    private var flutterApi: PermateAttributionFlutterApi? = null

    @Volatile
    private var hasActivity = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        PermateAttributionHostApi.setUp(binding.binaryMessenger, this)
        flutterApi = PermateAttributionFlutterApi(binding.binaryMessenger)
        synchronized(ownerLock) {
            attached.add(this)
            if (owner == null) claimDelegates()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PermateAttributionHostApi.setUp(binding.binaryMessenger, null)
        synchronized(ownerLock) {
            attached.remove(this)
            if (owner === this) {
                val next = attached.firstOrNull { it.hasActivity } ?: attached.firstOrNull()
                if (next != null) next.claimDelegates() else releaseDelegates()
            }
        }
        flutterApi = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        hasActivity = true
        synchronized(ownerLock) { claimDelegates() }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        hasActivity = false
    }

    override fun onDetachedFromActivity() {
        hasActivity = false
    }

    /** Caller must hold [ownerLock]. */
    private fun claimDelegates() {
        owner = this
        PermateAttribution.attributionDelegate = this
        PermateAttribution.deepLinkDelegate = this
    }

    override fun getSdkVersion(): String = PermateAttribution.SDK_VERSION

    override fun configure(appKey: String, options: AttributionOptionsDto) {
        val context = applicationContext ?: return
        PermateAttribution.configure(
            context = context,
            appKey = appKey,
            options = options.toNative(),
        )
        synchronized(ownerLock) {
            // A headless engine calling configure must not steal callbacks from the UI engine.
            if (hasActivity || owner?.hasActivity != true) claimDelegates()
        }
    }

    override fun start() {
        PermateAttribution.start()
    }

    override fun getAttribution(): AttributionResultDto? =
        PermateAttribution.getAttribution()?.toDto()

    override fun handleDeepLink(url: String): DeepLinkResultDto? {
        val uri = Uri.parse(url)
        return PermateAttribution.handleDeepLink(uri)?.toDto()
    }

    override fun handlePushNotification(payload: Map<String?, Any?>): Boolean {
        val cleaned = payload.mapNotNull { (key, value) ->
            key?.let { it to value }
        }.toMap()
        return PermateAttribution.handlePushNotification(cleaned)
    }

    override fun logEvent(name: String, params: Map<String?, Any?>?) {
        // Drop null keys/values (iOS plugin parity): native rejects the whole event on a null value.
        val sanitized = params?.mapNotNull { (key, value) ->
            if (key != null && value != null) key to value else null
        }?.toMap()?.takeIf { it.isNotEmpty() }
        PermateAttribution.logEvent(name, sanitized)
    }

    override fun reset() {
        PermateAttribution.reset()
    }

    override fun updatePushToken(token: String) {
        PermateAttribution.updatePushToken(token)
    }

    override fun refreshConfig(callback: (Result<RemoteConfigSnapshotDto>) -> Unit) {
        PermateAttribution.refreshConfig { result ->
            result.fold(
                onSuccess = { snapshot -> callback(Result.success(snapshot.toDto())) },
                onFailure = { error ->
                    callback(
                        Result.failure(
                            FlutterError(
                                "refresh_config_failed",
                                error.message ?: error.toString(),
                                null,
                            ),
                        ),
                    )
                },
            )
        }
    }

    override fun getIsDeactivated(): Boolean = PermateAttribution.isDeactivated

    override fun setIsDeactivated(value: Boolean) {
        PermateAttribution.isDeactivated = value
    }

    override fun getDisableAdvertisingIdentifier(): Boolean = PermateAttribution.disableAdvertisingIdentifier

    override fun setDisableAdvertisingIdentifier(value: Boolean) {
        PermateAttribution.disableAdvertisingIdentifier = value
    }

    override fun getDisableIDFVCollection(): Boolean = false

    override fun setDisableIDFVCollection(value: Boolean) {
        // IDFV is iOS-only; Android has no equivalent identifier to disable.
    }

    override fun getAdvertisingIdentifier(): String = ""

    override fun waitForATTUserAuthorization(timeoutSeconds: Double) {
        // ATT is iOS-only; no-op on Android.
    }

    override fun onAttributionSuccess(result: AttributionResult) {
        flutterApi?.onAttributionSuccess(result.toDto()) { /* ignore dart errors */ }
    }

    override fun onAttributionFailure(error: AttributionError) {
        val (code, message) = error.toFlutterFailure()
        flutterApi?.onAttributionFailure(code, message) { /* ignore */ }
    }

    override fun didResolveDeepLink(result: DeepLinkResult) {
        flutterApi?.didResolveDeepLink(result.toDto()) { /* ignore */ }
    }

    private fun AttributionError.toFlutterFailure(): Pair<String, String> {
        val message = this.message ?: toString()
        val code =
            when (this) {
                is AttributionError.InvalidAppKey -> "invalid_app_key"
                is AttributionError.BrandDisabled -> "brand_disabled"
                is AttributionError.Http -> "http"
                is AttributionError.NetworkFailure -> "network_failure"
            }
        return code to message
    }

    private fun AttributionOptionsDto.toNative(): AttributionOptions =
        AttributionOptions(
            environment = when (environment.lowercase()) {
                "staging" -> Environment.STAGING
                else -> Environment.PRODUCTION
            },
            baseUrl = baseUrl,
            logLevel = when (logLevel.lowercase()) {
                "verbose" -> LogLevel.VERBOSE
                else -> LogLevel.ERROR
            },
            sessionEnabled = sessionEnabled,
            minTimeBetweenSessions = minTimeBetweenSessionsMs,
            disableAdvertisingIdentifier = disableAdvertisingIdentifier,
        )

    private fun AttributionResult.toDto(): AttributionResultDto =
        AttributionResultDto(
            attributed = attributed,
            clickId = clickId,
            campaignId = campaignId,
            offerId = offerId,
            partnerId = partnerId,
            resolvedAt = resolvedAt,
            channel = channel,
            isActive = isActive,
            deferredParams = deferredParams?.mapKeys { it.key as String? },
        )

    private fun DeepLinkResult.toDto(): DeepLinkResultDto =
        DeepLinkResultDto(
            campaignId = campaignId,
            clickId = clickId,
            offerId = offerId,
            isDeferred = isDeferred,
            rawParams = rawParams.mapKeys { it.key as String? },
        )

    private fun RemoteConfigSnapshot.toDto(): RemoteConfigSnapshotDto =
        RemoteConfigSnapshotDto(
            isActive = isActive,
            cacheTtlSec = cacheTtlSec,
            fetchedAtMillis = fetchedAtMillis,
        )

    private companion object {
        val ownerLock = Any()

        /** Attach order; the first entry is usually the main (UI) engine. Guarded by [ownerLock]. */
        val attached = mutableListOf<PermateAttributionPlugin>()

        /** Instance currently registered as native delegate. Guarded by [ownerLock]. */
        var owner: PermateAttributionPlugin? = null

        /** Caller must hold [ownerLock]. */
        fun releaseDelegates() {
            owner = null
            PermateAttribution.attributionDelegate = null
            PermateAttribution.deepLinkDelegate = null
        }
    }
}
