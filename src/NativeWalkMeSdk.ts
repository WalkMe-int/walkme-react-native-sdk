import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * Codegen specification for the WalkMe native module.
 *
 * This is the SINGLE source of truth for the native surface on both
 * architectures:
 *
 *   • New Architecture — Codegen turns this file into the `NativeWalkMeSdkSpec`
 *     Java abstract class and the `NativeWalkMeSdkSpec` Obj-C protocol /
 *     `NativeWalkMeSdkSpecJSI` C++ binding that the TurboModule implements.
 *   • Legacy Architecture — `TurboModuleRegistry.get()` transparently falls back
 *     to `NativeModules.RNWalkMeSdk`, so the very same object is returned.
 *
 * The signatures below mirror the pre-existing bridge methods exactly (names,
 * arity, parameter types and `void` return), so the public `WalkMeSDK` JS API in
 * `index.js` is unchanged for consumers.
 *
 * NOTE: `Object` is Codegen's "unsafe object" (`NSDictionary *` / `ReadableMap`)
 * and is used deliberately — the WalkMe options/attribute bags are open-ended and
 * must keep forwarding unknown keys straight through to the native SDK.
 */
export interface Spec extends TurboModule {
  start(options: Object): void;
  stop(): void;
  restart(): void;
  startItemByID(itemId: number, deepLink: string | null): void;
  dismissItem(): void;
  setUserId(userId: string | null): void;
  setVariable(key: string, value: string | null): void;
  setEventUserVars(vars: Object): void;
  setLanguage(language: string): void;
  sendEvent(name: string, attributes: Object | null): void;
  setItemInfoListener(enable: boolean): void;
  setAnalyticsListener(enable: boolean): void;

  // Required by `NativeEventEmitter` on both architectures.
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.get<Spec>('RNWalkMeSdk');
