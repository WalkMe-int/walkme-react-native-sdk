package com.walkme.rn

import android.app.Application
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.walkme.api.WalkMeEventUserVarsKey
import com.walkme.api.WalkMeStartOptions
import com.walkme.api.WalkmeDataCenter
import com.walkme.api.analytics.WMAnalyticsListener
import com.walkme.api.info.WMItemInfo
import com.walkme.api.info.WMItemInfoListener

class RNWalkMeSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "RNWalkMeSdk"

    private fun emitEvent(name: String, body: WritableMap) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(name, body)
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

    @ReactMethod
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

        val application = reactApplicationContext.applicationContext as Application
        startSdk(startOptions, reactApplicationContext.currentActivity, application)
    }

    @ReactMethod
    fun stop() {
        sdkInstance.stop()
    }

    @ReactMethod
    fun restart() {
        sdkInstance.restart()
    }

    @ReactMethod
    fun startItemByID(itemId: Int, deepLink: String?) {
        sdkInstance.startItemByID(itemId, deepLink)
    }

    @ReactMethod
    fun dismissItem() {
        sdkInstance.dismissItem()
    }

    @ReactMethod
    fun setUserId(userId: String?) {
        sdkInstance.setUserId(userId)
    }

    @ReactMethod
    fun setVariable(key: String, value: String?) {
        sdkInstance.setVariable(key, value)
    }

    @ReactMethod
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

    @ReactMethod
    fun setLanguage(language: String) {
        sdkInstance.setLanguage(language)
    }

    @ReactMethod
    fun sendEvent(name: String, attributes: ReadableMap?) {
        val attrsMap: Map<String, Any?>? = attributes?.let { readableMapToMap(it) }
        sdkInstance.sendEvent(name, attrsMap)
    }

    @ReactMethod
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
        } else {
            sdkInstance.setItemInfoListener(null)
        }
    }

    @ReactMethod
    fun setAnalyticsListener(enable: Boolean) {
        if (enable) {
            sdkInstance.setAnalyticsListener(WMAnalyticsListener { eventName, params ->
                val map = Arguments.createMap()
                map.putString("eventName", eventName)
                map.putString("params", params.toString())
                emitEvent("walkme_analytics_event", map)
            })
        } else {
            sdkInstance.setAnalyticsListener(null)
        }
    }

    // Required by React Native's NativeEventEmitter
    @ReactMethod fun addListener(eventName: String) {}
    @ReactMethod fun removeListeners(count: Int) {}

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
}
