package com.walkme.rn

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReadableMap

/**
 * Legacy Architecture base class for [RNWalkMeSdkModule].
 *
 * This is the hand-written counterpart of the Codegen-generated
 * `NativeWalkMeSdkSpec` that the New Architecture build uses (see
 * `android/src/newarch/java/com/walkme/rn/RNWalkMeSdkSpec.kt`). It declares the
 * exact same method signatures as the generated spec, which is what allows
 * `android/src/main/java/com/walkme/rn/RNWalkMeSdkModule.kt` to be a single
 * source file shared by both architectures.
 *
 * The signatures are dictated by `src/NativeWalkMeSdk.ts`; keep the two in sync
 * when adding an API. Codegen enforces that on the New Architecture side, this
 * file is what keeps the Legacy side honest.
 *
 * Note: the `@ReactMethod` annotations deliberately live on the *concrete*
 * overrides in [RNWalkMeSdkModule], not here. `JavaModuleWrapper.findMethods()`
 * only inspects the base class when that base class implements `TurboModule`,
 * which this one does not; on the Legacy path RN reflects over the concrete
 * module's own declared methods instead.
 */
abstract class RNWalkMeSdkSpec(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    abstract fun start(options: ReadableMap)

    abstract fun stop()

    abstract fun restart()

    abstract fun startItemByID(itemId: Double, deepLink: String?)

    abstract fun dismissItem()

    abstract fun setUserId(userId: String?)

    abstract fun setVariable(key: String, value: String?)

    abstract fun setEventUserVars(vars: ReadableMap)

    abstract fun setLanguage(language: String)

    abstract fun sendEvent(name: String, attributes: ReadableMap?)

    abstract fun setItemInfoListener(enable: Boolean)

    abstract fun setAnalyticsListener(enable: Boolean)

    abstract fun addListener(eventName: String)

    abstract fun removeListeners(count: Double)
}
