package com.walkme.rn

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule

/**
 * The `RNWalkMeSdk` native module exposed to JavaScript.
 *
 * There is exactly one copy of this file. Its base class, `RNWalkMeSdkSpec`, is
 * resolved per build variant:
 *
 *  * Legacy Architecture -> `android/src/oldarch/.../RNWalkMeSdkSpec.kt`
 *    (a hand-written `ReactContextBaseJavaModule` subclass).
 *  * New Architecture -> `android/src/newarch/.../RNWalkMeSdkSpec.kt`, a
 *    `typealias` for the Codegen-generated `NativeWalkMeSdkSpec`, which
 *    implements `TurboModule`.
 *
 * All WalkMe logic lives in [WalkMeSdkBridge], so this class stays a pure
 * pass-through and neither architecture duplicates any behavior.
 *
 * The `@ReactMethod` annotations are required on these concrete overrides for
 * the Legacy path: `JavaModuleWrapper.findMethods()` reflects over the base
 * class only when the base class implements `TurboModule`, and the Legacy
 * `RNWalkMeSdkSpec` does not. On the New Architecture path RN reads the
 * annotations off the generated spec instead, so they are simply redundant
 * there — never harmful.
 */
@ReactModule(name = RNWalkMeSdkModule.NAME)
class RNWalkMeSdkModule(reactContext: ReactApplicationContext) : RNWalkMeSdkSpec(reactContext) {

    private val bridge = WalkMeSdkBridge(reactContext)

    override fun getName(): String = RNWalkMeSdkModule.NAME

    @ReactMethod
    override fun start(options: ReadableMap) {
        bridge.start(options)
    }

    @ReactMethod
    override fun stop() {
        bridge.stop()
    }

    @ReactMethod
    override fun restart() {
        bridge.restart()
    }

    @ReactMethod
    override fun startItemByID(itemId: Double, deepLink: String?) {
        bridge.startItemByID(itemId, deepLink)
    }

    @ReactMethod
    override fun dismissItem() {
        bridge.dismissItem()
    }

    @ReactMethod
    override fun setUserId(userId: String?) {
        bridge.setUserId(userId)
    }

    @ReactMethod
    override fun setVariable(key: String, value: String?) {
        bridge.setVariable(key, value)
    }

    @ReactMethod
    override fun setEventUserVars(vars: ReadableMap) {
        bridge.setEventUserVars(vars)
    }

    @ReactMethod
    override fun setLanguage(language: String) {
        bridge.setLanguage(language)
    }

    @ReactMethod
    override fun sendEvent(name: String, attributes: ReadableMap?) {
        bridge.sendEvent(name, attributes)
    }

    @ReactMethod
    override fun setItemInfoListener(enable: Boolean) {
        bridge.setItemInfoListener(enable)
    }

    @ReactMethod
    override fun setAnalyticsListener(enable: Boolean) {
        bridge.setAnalyticsListener(enable)
    }

    /**
     * Required by `NativeEventEmitter`. Events are delivered through
     * `RCTDeviceEventEmitter`, which does its own subscription bookkeeping, so
     * there is nothing to do here — but the methods must exist, because under
     * the New Architecture `NativeEventEmitter` invokes them on the module.
     */
    @ReactMethod
    override fun addListener(eventName: String) = Unit

    @ReactMethod
    override fun removeListeners(count: Double) = Unit

    override fun invalidate() {
        bridge.invalidate()
        super.invalidate()
    }

    companion object {
        const val NAME: String = "RNWalkMeSdk"
    }
}
