package com.walkme.rn

import android.app.Application
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.walkme.api.WalkMeEventUserVarsKey
import com.walkme.api.WalkMeStartOptions
import com.walkme.api.WalkmeDataCenter
import com.walkme.api.analytics.WMAnalyticsListener
import com.walkme.api.info.WMItemInfo
import com.walkme.api.info.WMItemInfoListener

/**
 * Architecture-agnostic WalkMe adapter.
 *
 * This class holds ALL of the bridge's business logic: argument marshalling,
 * WalkMe SDK invocation and native -> JS event emission. It knows nothing about
 * TurboModules or legacy NativeModules, which is what allows the Legacy and the
 * New Architecture module wrappers ([RNWalkMeSdkModule] on top of the
 * arch-specific `RNWalkMeSdkSpec`) to be thin, duplication-free pass-throughs.
 *
 * The WalkMe SDK entry point itself is supplied by the flavor-specific
 * `WalkMeSdkProvider.kt` (`src/WalkMe` vs `src/WalkMeEditor`), so Power Mode
 * selection is orthogonal to the React Native architecture.
 */
internal class WalkMeSdkBridge(private val reactContext: ReactApplicationContext) {

    /**
     * Tracks whether *this* bridge instance installed the SDK-level listeners, so
     * [invalidate] can detach them when the React instance goes away (reload,
     * teardown). Without this the WalkMe SDK singleton would keep a strong
     * reference to a dead ReactApplicationContext across a RN reload and events
     * would be emitted into a destroyed JS runtime.
     */
    private var itemInfoListenerAttached = false
    private var analyticsListenerAttached = false

    // region JS <- native events

    private fun emitEvent(name: String, body: WritableMap) {
        if (!reactContext.hasActiveReactInstance()) return
        // `getJSModule` is nullable under Bridgeless (RN >= 0.74 returns `T?`) and a
        // platform type on the bridge, so the safe call compiles and is correct on both.
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            ?.emit(name, body)
    }

    private fun itemInfoToMap(itemInfo: WMItemInfo): WritableMap {
        val map = Arguments.createMap()
        map.putString("itemId", itemInfo.itemId)
        itemInfo.itemActionType?.let { map.putString("itemActionType", it) }
        val ud = Arguments.createMap()
        with(itemInfo.userData) {
            ud.putDouble("sessionDuration", sessionDuration)
            ud.putString("deviceVersion", deviceVersion)
            ud.putString("deviceId", deviceId)
            ud.putString("deviceModel", deviceModel)
            ud.putString("deviceOrientation", deviceOrientation)
            ud.putString("appVersion", appVersion)
            ud.putString("appName", appName)
            ud.putString("locale", locale)
            ud.putString("sdkVer", sdkVer)
            ud.putString("sessionId", sessionId)
            ud.putString("isNewUser", isNewUser)
            ud.putString("timezone", timezone)
            ud.putString("network", network)
            ud.putString("systemName", systemName)
            ud.putString("timestamp", timestamp)
            val attrs = Arguments.createMap()
            userAttributesMap.forEach { (k, v) ->
                when (v) {
                    null      -> attrs.putNull(k)
                    is Boolean -> attrs.putBoolean(k, v)
                    is Int    -> attrs.putInt(k, v)
                    is Double -> attrs.putDouble(k, v)
                    is String -> attrs.putString(k, v)
                    else      -> attrs.putString(k, v.toString())
                }
            }
            ud.putMap("userAttributesMap", attrs)
        }
        map.putMap("userData", ud)
        return map
    }

    // endregion

    // region WalkMe API

    fun start(options: ReadableMap) {
        val systemGuid = options.getString("systemGuid")
            ?: throw IllegalArgumentException("start: 'systemGuid' is required")

        val environment = options.getString("environment") ?: "Production"
        val dataCenterStr = options.getString("dataCenter") ?: "prod"
        val dataCenter: WalkmeDataCenter = when (dataCenterStr) {
            "prod" -> WalkmeDataCenter.prod
            "eu"   -> WalkmeDataCenter.eu
            "us01" -> WalkmeDataCenter.us01
            "eu01" -> WalkmeDataCenter.eu01
            else   -> WalkmeDataCenter.Custom(dataCenterStr)
        }

        val startOptions = WalkMeStartOptions(
            systemGuid = systemGuid,
            environment = environment,
            dataCenter = dataCenter,
        ).apply {
            if (options.hasKey("analyticsEnabled")) analyticsEnabled = options.getBoolean("analyticsEnabled")
            if (options.hasKey("localLogsEnabled")) localLogsEnabled = options.getBoolean("localLogsEnabled")
        }

        val application = reactContext.applicationContext as Application
        startSdk(startOptions, reactContext.currentActivity, application)
    }

    fun stop() {
        sdkInstance.stop()
    }

    fun restart() {
        sdkInstance.restart()
    }

    fun startItemByID(itemId: Double, deepLink: String?) {
        sdkInstance.startItemByID(itemId.toInt(), deepLink)
    }

    fun dismissItem() {
        sdkInstance.dismissItem()
    }

    fun setUserId(userId: String?) {
        sdkInstance.setUserId(userId)
    }

    fun setVariable(key: String, value: String?) {
        sdkInstance.setVariable(key, value)
    }

    fun setEventUserVars(vars: ReadableMap) {
        val keyMap: Map<String, WalkMeEventUserVarsKey> =
            WalkMeEventUserVarsKey.entries.associateBy { it.value }

        val result = mutableMapOf<WalkMeEventUserVarsKey, String>()
        val iterator = vars.keySetIterator()
        while (iterator.hasNextKey()) {
            val jsKey = iterator.nextKey()
            val sdkKey = keyMap[jsKey]
                ?: throw IllegalArgumentException("setEventUserVars: unknown key '$jsKey'. Valid keys: ${keyMap.keys}")
            result[sdkKey] = vars.getString(jsKey) ?: continue
        }

        sdkInstance.setEventUserVars(result)
    }

    fun setLanguage(language: String) {
        sdkInstance.setLanguage(language)
    }

    fun sendEvent(name: String, attributes: ReadableMap?) {
        val attrsMap: Map<String, Any?>? = attributes?.let { readableMapToMap(it) }
        sdkInstance.sendEvent(name, attrsMap)
    }

    fun setItemInfoListener(enable: Boolean) {
        if (enable) {
            sdkInstance.setItemInfoListener(object : WMItemInfoListener {
                override fun onItemPresented(itemInfo: WMItemInfo) {
                    emitEvent("walkme_item_presented", itemInfoToMap(itemInfo))
                }
                override fun onItemDismissed(itemInfo: WMItemInfo) {
                    emitEvent("walkme_item_dismissed", itemInfoToMap(itemInfo))
                }
                override fun onItemAction(itemInfo: WMItemInfo, args: Map<String, String>?) {
                    val map = itemInfoToMap(itemInfo)
                    args?.let {
                        val argsMap = Arguments.createMap()
                        it.forEach { (k, v) -> argsMap.putString(k, v) }
                        map.putMap("args", argsMap)
                    }
                    emitEvent("walkme_item_action", map)
                }
            })
            itemInfoListenerAttached = true
        } else {
            sdkInstance.setItemInfoListener(null)
            itemInfoListenerAttached = false
        }
    }

    fun setAnalyticsListener(enable: Boolean) {
        if (enable) {
            sdkInstance.setAnalyticsListener(WMAnalyticsListener { eventName, params ->
                val map = Arguments.createMap()
                map.putString("eventName", eventName)
                map.putString("params", params.toString())
                emitEvent("walkme_analytics_event", map)
            })
            analyticsListenerAttached = true
        } else {
            sdkInstance.setAnalyticsListener(null)
            analyticsListenerAttached = false
        }
    }

    // endregion

    /**
     * Detach any SDK listener this bridge installed. Called from the module's
     * `invalidate()` so a React instance reload does not leave the WalkMe SDK
     * singleton holding a listener bound to a destroyed ReactApplicationContext.
     */
    fun invalidate() {
        if (itemInfoListenerAttached) {
            sdkInstance.setItemInfoListener(null)
            itemInfoListenerAttached = false
        }
        if (analyticsListenerAttached) {
            sdkInstance.setAnalyticsListener(null)
            analyticsListenerAttached = false
        }
    }

    // region ReadableMap/Array -> Kotlin collections

    private fun readableMapToMap(map: ReadableMap): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        val iterator = map.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            result[key] = when (map.getType(key)) {
                ReadableType.Null    -> null
                ReadableType.Boolean -> map.getBoolean(key)
                ReadableType.Number  -> map.getDouble(key)
                ReadableType.String  -> map.getString(key)
                ReadableType.Map     -> readableMapToMap(map.getMap(key)!!)
                ReadableType.Array   -> readableArrayToList(map.getArray(key)!!)
            }
        }
        return result
    }

    private fun readableArrayToList(array: ReadableArray): List<Any?> {
        val result = mutableListOf<Any?>()
        for (i in 0 until array.size()) {
            result += when (array.getType(i)) {
                ReadableType.Null    -> null
                ReadableType.Boolean -> array.getBoolean(i)
                ReadableType.Number  -> array.getDouble(i)
                ReadableType.String  -> array.getString(i)
                ReadableType.Map     -> readableMapToMap(array.getMap(i)!!)
                ReadableType.Array   -> readableArrayToList(array.getArray(i)!!)
            }
        }
        return result
    }

    // endregion
}
