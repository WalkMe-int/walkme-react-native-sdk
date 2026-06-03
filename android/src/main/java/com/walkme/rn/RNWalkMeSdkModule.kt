package com.walkme.rn

import android.app.Activity
import com.facebook.react.bridge.*
import com.walkme.api.WalkMeEventUserVarsKey
import com.walkme.api.WalkMeStartOptions
import com.walkme.api.WalkmeDataCenter

class RNWalkMeSdkModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "RNWalkMeSdk"

    private fun requireActivity(): Activity =
        reactApplicationContext.currentActivity ?: error("No foreground Activity available")

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

        sdkInstance.start(requireActivity(), startOptions)
    }

    @ReactMethod
    fun stop() {
        sdkInstance.stop()
    }

    @ReactMethod
    fun startItemByID(itemId: Int, deepLink: String?) {
        sdkInstance.startItemByID(itemId, deepLink)
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
