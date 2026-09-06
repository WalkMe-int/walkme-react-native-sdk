#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <WalkMeSdkSpec/WalkMeSdkSpec.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * The single React Native module for the WalkMe SDK, shared by both
 * architectures.
 *
 * Legacy Architecture: an ordinary `RCTEventEmitter` NativeModule exported under
 * the name `RNWalkMeSdk` via `RCT_EXPORT_MODULE()`.
 *
 * New Architecture: the same class additionally conforms to the Codegen-
 * generated `NativeWalkMeSdkSpec` protocol and vends a `NativeWalkMeSdkSpecJSI`
 * from `getTurboModule:`, so `RCTTurboModuleManager` binds it as a real
 * TurboModule. `RCTEventEmitter` is bridgeless-safe: it emits through
 * `callableJSModules`, which the TurboModule manager injects.
 *
 * All WalkMe interaction lives in `WMRNSdkProvider` (Swift, see
 * `ios/Sources/Shared/WalkMeSdkProvider.swift`), so nothing about the WalkMe SDK
 * — including which flavor was linked — is duplicated per architecture.
 */
@interface RNWalkMeSdk : RCTEventEmitter <RCTBridgeModule
#ifdef RCT_NEW_ARCH_ENABLED
                                         ,
                                         NativeWalkMeSdkSpec
#endif
                                         >
@end

NS_ASSUME_NONNULL_END
