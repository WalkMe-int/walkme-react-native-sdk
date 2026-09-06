# @walkme-mobile/react-native-sdk

React Native bridge for the WalkMe and WalkMe Power Mode (WalkMeEditor) SDKs on **Android** and **iOS**.

---

## Overview

- One JavaScript API (`WalkMeSDK`) bridges to the native SDK on both platforms.
- Works on the **Legacy Architecture**, the **New Architecture (TurboModules)** and **Bridgeless** mode — the same import, the same methods, the same events. Nothing in your JavaScript changes.
- Two **flavors**: standard **WalkMe** and Power Mode **WalkMeEditor**. Pick the flavor once in `package.json` — no code changes needed.
- The bridge pulls the correct native SDK automatically and, on iOS, supplies the required Lottie dependency.

| | Android | iOS |
|---|---|---|
| Min OS | Android 7.0 (API 24) | iOS 14 |
| Native SDK source | JitPack | Swift Package Manager |
| Required RN version | **≥ 0.75** | **≥ 0.75** |
| Architectures | Legacy • New • Bridgeless | Legacy • New • Bridgeless |

---

## React Native Architecture Support

The bridge supports the **Legacy Architecture**, the **New Architecture (TurboModules)** and **Bridgeless** mode from a single package. Nothing in your app has to declare which one you are on — the bridge detects it at build time and picks the matching native path.

| | How the module is resolved | What is built |
|---|---|---|
| Legacy Architecture | `NativeModules.RNWalkMeSdk` (via `TurboModuleRegistry.get`, which falls back automatically) | Android: `src/oldarch` base class • iOS: plain `RCTEventEmitter` + `RCT_EXPORT_METHOD` |
| New Architecture | TurboModule proxy | Android: Codegen `NativeWalkMeSdkSpec` • iOS: `NativeWalkMeSdkSpec` protocol + `NativeWalkMeSdkSpecJSI` |
| Bridgeless | TurboModule proxy, no bridge | Same as New Architecture; events are emitted without touching `RCTBridge` / the legacy event dispatcher |

There is **one** implementation of the WalkMe logic per platform. The architecture-specific code is only the thin base class / registration glue:

```
JS  →  TurboModuleRegistry.get('RNWalkMeSdk')
       │
       ├─ Android  RNWalkMeSdkModule (@ReactMethod)  →  WalkMeSdkBridge  →  WalkMe Android SDK
       │            └ base class differs per arch (src/oldarch | src/newarch)
       │
       └─ iOS      RNWalkMeSdk.mm (RCT_EXPORT_METHOD) →  WMRNSdkProvider  →  WalkMe iOS SDK
                    └ conforms to the generated spec only under RCT_NEW_ARCH_ENABLED
```

### How the architecture is detected

| Platform | Signal | Fallback |
|---|---|---|
| Android | `newArchEnabled` (or `react.newArchEnabled`) in your `android/gradle.properties` | React Native ≥ 0.82, where the Legacy Architecture no longer exists, is treated as New Architecture |
| iOS | `RCT_NEW_ARCH_ENABLED` — the flag React Native's own `install_modules_dependencies` sets during `pod install` | Whatever React Native defaults to for your version |

You do not set anything WalkMe-specific for this. Flip `newArchEnabled` (Android) or `RCT_NEW_ARCH_ENABLED` (iOS) the way you would for any other library and rebuild.

### Compatibility matrix

Verified by building the example apps in this repository end-to-end — each installs the bridge through React Native's own autolinking, exactly as a consuming app does:

| React Native | Architecture | Android | iOS |
|---|---|---|---|
| 0.85.3 | New (Bridgeless) | ✅ Debug + Release (R8) | ✅ Debug + Release |
| 0.81.4 | Legacy | ✅ Debug + Release (R8) | ✅ Debug + Release |

- **Minimum supported React Native: 0.75.** This is set by iOS, not by the architecture work: the WalkMe iOS SDK ships only via Swift Package Manager and the bridge integrates it with React Native's `spm_dependency` helper, which was added in RN 0.75. The minimum was **not** raised by this change.
- React Native **0.82 and later removed the Legacy Architecture**; on those versions the bridge builds the New Architecture path only, which is the only thing that exists there.
- Versions between 0.75 and 0.81 are expected to work on both architectures — the same code paths are used — but only the two rows above were actually built and are therefore the only ones claimed.
- The RN 0.81 iOS builds need one **example-app** Podfile tweak that has nothing to do with this bridge: React Native ≤ 0.81 vendors fmt 11.0.2, which the Clang in Xcode 16.3+ rejects under C++20. See the Troubleshooting table.

---

## Installation

```sh
npm install @walkme-mobile/react-native-sdk
```

The bridge is autolinked — no manual native registration needed.

---

## Select a Flavor

Add a `walkme` block to your app's `package.json`. Both platforms read this at build time — you only set it once:

```json
{
  "dependencies": {
    "@walkme-mobile/react-native-sdk": "..."
  },
  "walkme": {
    "walkmeMode": "WalkMe"
  }
}
```

| `walkmeMode` value | SDK |
|---|---|
| omitted, or `"WalkMe"` | standard **WalkMe** (default) |
| `"WalkMeEditor"` | Power Mode (**WalkMeEditor**) |

The value is case-insensitive. An unrecognized value fails the build with a clear error.

---

## Android Setup

### 1. Apply the bridge Gradle script in `android/app/build.gradle`

Add one line at the top of your app's `build.gradle`:

```gradle
apply from: "../../node_modules/@walkme-mobile/react-native-sdk/android/walkme.gradle"
```

The script reads `walkmeMode` from `package.json`, wires up the correct flavor, and adds the JitPack repository — no manual repo config or `missingDimensionStrategy` needed.

### 2. (Optional) Pin a specific SDK version

In your root `android/build.gradle`:

```gradle
ext {
    walkmeVersion       = '1.1.0'  // for WalkMe flavor
    walkmeEditorVersion = '1.1.0'  // for WalkMeEditor flavor
}
```

If omitted, the latest published version is used.

---

## iOS Setup

> **Requires React Native ≥ 0.75.** The WalkMe iOS SDK ships only via Swift Package Manager, and the bridge pulls it in using RN's `spm_dependency` helper (added in RN 0.75).

The bridge pulls the correct WalkMe SPM package **and** the matching Lottie dependency, and ships the required CocoaPods `post_install` logic as a helper. You do **not** install `lottie-react-native`, set any environment variable, or copy any embedding script.

### 1. Wire up the `ios/Podfile`

Two additions, alongside what RN's template already generates:

```ruby
# (a) Load the bridge CocoaPods helpers
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "@walkme-mobile/react-native-sdk/scripts/walkme_podfile.rb",
    {paths: [process.argv[1]]},
  )', __dir__]).strip

target 'YourApp' do
  config = use_native_modules!
  use_react_native!(:path => config[:reactNativePath])

  post_install do |installer|
    react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => false)

    # (b) Embed the WalkMe + Lottie SPM frameworks into the app bundle
    walkme_post_install(installer)
  end
end
```

> No `AppDelegate` changes are needed on either architecture — the module registers itself through `RCT_EXPORT_MODULE()`, and CocoaPods autolinking wires it into the TurboModule provider when the New Architecture is on.

### 2. Install pods & run

```sh
npm install
cd ios && pod install && cd ..
npx react-native run-ios
```

To switch flavors, edit `walkme.walkmeMode` in `package.json` and re-run `pod install`.

> **CI / one-off override:** `WALKME_FLAVOR=WalkMeEditor pod install` takes precedence over `package.json`.

---

## How the iOS integration scripts work

The bridge ships **`scripts/walkme_podfile.rb`** inside the npm package and exposes one public function — `walkme_post_install(installer)` — that you call from your Podfile's `post_install`. It performs the one fix that **CocoaPods cannot do from a podspec alone** (a podspec can only configure its *own* pod target, not the app bundle). Keeping the logic in the bridge means it's version-locked to the SDK and never copy/pasted.

### `walkme_embed_spm_frameworks(installer)` — embed the SPM frameworks

Rsyncs and codesigns `WalkMe*.framework` and `Lottie.framework` into the app bundle. `spm_dependency` links them to the Pods target but never embeds them in the app, so without this the app aborts at launch with `dyld: Library not loaded: @rpath/WalkMeEditor.framework` or `…/Lottie.framework/Lottie`. The build phase is found-or-created by name, so re-running `pod install` never duplicates it.

### Why Lottie comes from the bridge

Both WalkMe SDK flavors hard-link `@rpath/Lottie.framework/Lottie` at runtime but do **not** declare Lottie themselves — their `Package.swift` expects the host to provide it — and their `.swiftinterface` contains `import Lottie`, so the module must be on the bridge's search path to compile too.

The bridge supplies it via [`lottie-spm`](https://github.com/airbnb/lottie-spm), Airbnb's official SPM distribution of the **prebuilt dynamic `Lottie.xcframework`**. Because it's a shared SPM package, SPM unifies it with a host app that also uses `lottie-spm`. This replaced an earlier `lottie-ios` **pod** dependency, which was the *sole* reason the bridge used to require `use_frameworks! :linkage => :dynamic` — that pod only produces a dynamic `Lottie.framework` under dynamic linkage, and being built from source it also needed a `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` patch to match the prebuilt WalkMe frameworks' resilient ABI. The prebuilt xcframework needs neither.

> The only thing CocoaPods won't let the bridge do automatically is inject the `post_install` call itself (that would require a CocoaPods plugin). Hence the single `walkme_post_install(installer)` line in your Podfile.

---

## Usage

### Quick start

In your root component (e.g. `App.tsx`), call `start` once on mount:

```js
import { useEffect } from 'react';
import WalkMeSDK from '@walkme-mobile/react-native-sdk';

useEffect(() => {
  WalkMeSDK.start({ systemGuid: 'YOUR_SYSTEM_GUID' });
}, []);
```

Replace `YOUR_SYSTEM_GUID` with the GUID from your WalkMe console. All other `start` options are optional — see [`WalkMeStartOptions`](#walkmestartoptions) below.

### Other methods

```js
WalkMeSDK.stop();
WalkMeSDK.restart();
WalkMeSDK.setUserId('user-123');
WalkMeSDK.setVariable('plan', 'premium');
WalkMeSDK.setEventUserVars({ name: 'John Doe', role: 'admin' });
WalkMeSDK.setLanguage('en');
WalkMeSDK.sendEvent('button_clicked', { screen: 'home' });
WalkMeSDK.startItemByID(42, null);
WalkMeSDK.dismissItem();
```

### Item-info listener

Register callbacks for item lifecycle events. Pass `null` to clear.

```js
WalkMeSDK.setItemInfoListener({
  onItemPresented: (info) => console.log('Item shown:', info.itemId),
  onItemDismissed: (info) => console.log('Item dismissed:', info.itemId),
  onItemAction:    (info) => console.log('Item action:', info.itemActionType, info.args), // Android only
});

// Clear when no longer needed
WalkMeSDK.setItemInfoListener(null);
```

### Analytics listener

Register a callback for analytics events posted by the SDK. Pass `null` to clear.

```js
WalkMeSDK.setAnalyticsListener((event) => {
  console.log('Analytics event:', event.eventName, event.params);
});

// Clear when no longer needed
WalkMeSDK.setAnalyticsListener(null);
```

---

## API Reference

| Method | Parameters | Description |
|---|---|---|
| `start(options)` | `WalkMeStartOptions` | Start the SDK |
| `stop()` | — | Stop the SDK |
| `restart()` | — | Restart the SDK with the same options |
| `startItemByID(itemId, deepLink?)` | `number`, `string?` | Launch a specific item |
| `dismissItem()` | — | Dismiss the active item |
| `setUserId(userId)` | `string \| null` | Set the end-user ID |
| `setVariable(key, value)` | `string`, `string \| null` | Set a segmentation variable |
| `setEventUserVars(vars)` | `WalkMeEventUserVars` | Set event user attributes |
| `setLanguage(language)` | `string` | Set the display language |
| `sendEvent(name, attributes?)` | `string`, `object?` | Send a custom event |
| `setItemInfoListener(listener)` | `WMItemInfoListener \| null` | Register or clear item lifecycle callbacks |
| `setAnalyticsListener(listener)` | `function \| null` | Register or clear analytics event callback |

### `WalkMeStartOptions`

| Property | Type | Required | Default |
|---|---|---|---|
| `systemGuid` | `string` | ✅ | — |
| `environment` | `string` | | `'Production'` |
| `dataCenter` | `string` | | `'prod'` |
| `analyticsEnabled` | `boolean` | | `true` |
| `localLogsEnabled` | `boolean` | | `false` |

### `WMItemInfoListener`

| Callback | Payload | Platform |
|---|---|---|
| `onItemPresented(info)` | `WMItemInfo` | Android + iOS |
| `onItemDismissed(info)` | `WMItemInfo` | Android + iOS |
| `onItemAction(info)` | `WMItemInfo` (with `args` map) | Android only |

### `WMItemInfo`

| Field | Type | Platform |
|---|---|---|
| `itemId` | `string` (Android) / `number` (iOS) | Both |
| `itemActionType` | `string?` | Android |
| `itemType` | `string?` | iOS |
| `action` | `string?` | iOS |
| `args` | `Record<string, string>?` | Android (`onItemAction` only) |
| `userData` | `WMUserData` | Both |

### `WMAnalyticsEvent`

| Field | Type | Description |
|---|---|---|
| `eventName` | `string` | Event type, e.g. `"play"`, `"click"`, `"activity"` |
| `params` | `string` | Full event payload as a JSON string |

---

## Troubleshooting (iOS)

| Symptom | Cause | Fix |
|---|---|---|
| `pod install` fails: *Unknown walkmeMode "…"* | Typo in `walkme.walkmeMode` | Use exactly `WalkMe` or `WalkMeEditor` (any casing). |
| Launch crash: `dyld: Library not loaded: @rpath/WalkMe….framework` or `@rpath/Lottie.framework/Lottie` | Framework not embedded | Ensure `walkme_post_install(installer)` runs — it adds the embed phase. |
| `pod install` warns *“using swift package(s) … with static linking”* | RN's advisory SPM warning | Ignore it — verified working with static pods. You do **not** need `use_frameworks!`. |
| Build fails in `Pods/fmt/include/fmt/format-inl.h`: *call to consteval function … is not a constant expression* | React Native ≤ 0.81 vendors fmt 11.0.2, which Clang from Xcode 16.3+ rejects under C++20. Unrelated to this bridge — fmt fixed it in 11.1 and React Native picked it up in 0.82. | Build the `fmt` pod as C++17 from your Podfile's `post_install` (see `examples/legacy/ios/Podfile`), or use an older Xcode. |

---

## Upgrading

If you are already using this bridge, **no JavaScript changes are required** — the public `WalkMeSDK` API, its method names, parameters, return values and the item-info / analytics callbacks are all unchanged. Rebuild and you are done.

Two things are worth knowing:

- **`android/walkme.gradle` now applies its flavor strategy lazily.** The documented placement (first line of `android/app/build.gradle`, before `apply plugin: "com.android.application"`) previously failed with `Could not find method android()`. The script now waits for the Android plugin to be applied, so it works at the top or the bottom of the file. No change on your side.
- **iOS no longer needs a per-flavor source tree.** Flavor selection moved into a single Swift adapter behind a compile-time flag that the podspec sets from your `package.json`. If you had pinned anything to the old `ios/Sources/WalkMe*` paths, drop it — `pod install` handles this.

Nothing about the `walkme.walkmeMode` configuration changed: same key, same values, same place, same build-time behavior on both platforms.

---

## Example apps

Two runnable apps under `examples/` exercise every public API and both listeners, one per architecture:

| App | React Native | Architecture | Flavor | Android package |
|---|---|---|---|---|
| [`examples/new-arch`](examples/new-arch) | 0.85.3 | New Architecture (bridgeless) | `WalkMeEditor` (Power Mode) | `com.walkmeexample` |
| [`examples/legacy`](examples/legacy) | 0.81.4 | Legacy Architecture | `WalkMeEditor` (Power Mode) | `com.walkmeexamplelegacy` |

Both share the same `App.tsx` — nothing in it is architecture-aware, which is the whole point. The app header prints which architecture the JS runtime actually resolved, so you can confirm the bridge is running where you expect.

Each app depends on the bridge as `file:../..`, a link to this checkout, so it always runs the sources on your current branch:

```sh
cd examples/new-arch    # or examples/legacy
npm install
npm start               # Metro
npm run android         # or: npm run ios
```

Building needs **Node ≥ 20.19.4** and `ANDROID_HOME`. APKs are standalone by default — the JS bundle is compiled into every variant and the app never contacts a dev server — so `./android/gradlew -p android assembleDebug` produces a file that runs on its own. See each app's README for the details.

---

## License

Commercial
