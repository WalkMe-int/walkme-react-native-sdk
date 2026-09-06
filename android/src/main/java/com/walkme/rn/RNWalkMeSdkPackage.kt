package com.walkme.rn

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

/**
 * Registers [RNWalkMeSdkModule] with React Native.
 *
 * `BaseReactPackage` is the registration API that serves both architectures: on
 * the Legacy Architecture RN builds the NativeModule registry from
 * [getReactModuleInfoProvider] and instantiates lazily through [getModule];
 * under the New Architecture the TurboModule manager uses the very same two
 * methods. `isTurboModule` is derived from the module class itself, so the
 * value is automatically correct for whichever variant was compiled.
 *
 * The class name and constructor are referenced by `react-native.config.js`
 * for autolinking and must not change.
 */
class RNWalkMeSdkPackage : BaseReactPackage() {

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? =
        if (name == RNWalkMeSdkModule.NAME) RNWalkMeSdkModule(reactContext) else null

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider =
        ReactModuleInfoProvider {
            mapOf(
                RNWalkMeSdkModule.NAME to
                    ReactModuleInfo(
                        /* name = */ RNWalkMeSdkModule.NAME,
                        /* className = */ RNWalkMeSdkModule::class.java.name,
                        /* canOverrideExistingModule = */ false,
                        /* needsEagerInit = */ false,
                        /* isCxxModule = */ false,
                        /* isTurboModule = */
                        ReactModuleInfo.classIsTurboModule(RNWalkMeSdkModule::class.java),
                    )
            )
        }

    override fun createViewManagers(
        reactContext: ReactApplicationContext
    ): List<ViewManager<*, *>> = emptyList()
}
