# @walkme/react-native-sdk

React Native bridge for the WalkMe SDK — supports both standard (WalkMe) and Power Mode (WalkMeEditor) on Android and iOS.

---

## Installation

```sh
npm install @walkme/react-native-sdk
```

---

## Android Setup

### 1. Add JitPack to your root `android/build.gradle`

```gradle
allprojects {
    repositories {
        maven { url 'https://jitpack.io' }
    }
}
```

### 2. Choose a flavor in `android/app/build.gradle`

Add `missingDimensionStrategy` inside `defaultConfig`:

```gradle
android {
    defaultConfig {
        // Use 'WalkMe' for the standard SDK, or 'WalkMeEditor' for Power Mode
        missingDimensionStrategy 'walkmeMode', 'WalkMe'
    }
}
```

The bridge automatically includes the correct WalkMe SDK — no extra `implementation` line needed.

### 3. (Optional) Pin a specific SDK version

In your root `android/build.gradle`:

```gradle
ext {
    walkmeVersion       = '1.2.3'  // for WalkMe flavor
    walkmeEditorVersion = '1.2.3'  // for WalkMeEditor flavor
}
```

---

## iOS Setup

> **Requires React Native ≥ 0.75.** The WalkMe iOS SDK ships only via Swift Package
> Manager, and the bridge pulls it in using React Native's `spm_dependency` helper,
> which was introduced in RN 0.75.

### 1. Enable dynamic frameworks

`spm_dependency` requires dynamic framework linking. In your `ios/Podfile`:

```ruby
use_frameworks! :linkage => :dynamic
```

### 2. Install pods

The bridge is autolinked — no manual Xcode package step is needed.

```sh
# Standard WalkMe SDK (default)
cd ios && pod install

# Power Mode (WalkMeEditor) — select the flavor at install time
cd ios && WALKME_FLAVOR=WalkMeEditor pod install
```

The correct WalkMe SPM package (`walkme-ios-sdk` or `walkme-ios-sdk-editor`) is pulled
in automatically based on `WALKME_FLAVOR`.

> No `AppDelegate` changes are needed — `RCT_EXTERN_MODULE` auto-registers the native module.

### 3. Add Lottie (required for both flavors)

**Both** the standard **WalkMe** and **WalkMeEditor** flavors depend on
[Lottie](https://github.com/airbnb/lottie-ios) at runtime. Add it to your app — for
example via `lottie-react-native`:

```sh
npm install lottie-react-native
```

WalkMeEditor's binary framework is compiled against a **library-evolution (resilient)**
build of Lottie. `lottie-react-native` provides Lottie through the from-source
`lottie-ios` CocoaPod, which is **not** built with library evolution — so the app
crashes at launch with:

```
dyld: Symbol not found: _$s6Lottie0A8LoopModeO4loopyA2CmFWC  (LottieLoopMode.loop)
Referenced from: .../WalkMeEditor.framework/WalkMeEditor
Expected in:     .../Lottie.framework/Lottie
```

Fix it by building `lottie-ios` with library evolution. Add this to the `post_install`
block of your `ios/Podfile`:

```ruby
post_install do |installer|
  react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => false)

  # WalkMeEditor links Lottie's resilient (library-evolution) ABI. lottie-react-native's
  # lottie-ios pod is built from source without it, so build it with library evolution to
  # match — otherwise the app crashes at launch with "Symbol not found: ...LottieLoopMode.loop".
  installer.pods_project.targets.each do |t|
    if t.name == 'lottie-ios'
      t.build_configurations.each do |c|
        c.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end
  end
end
```

### 4. Install & run (Power Mode example)

```sh
# 1. Install JS deps (bridge + Lottie)
npm install

# 2. Install pods with the WalkMeEditor flavor selected
cd ios && WALKME_FLAVOR=WalkMeEditor pod install && cd ..

# 3. Build & run
npx react-native run-ios
```

> `WALKME_FLAVOR` is read at `pod install` time. Omitting it falls back to the standard
> `WalkMe` flavor, so a plain `pod install` (or `npx react-native run-ios` without first
> running the flavored `pod install`) will pull the wrong SDK. Re-run the flavored
> `pod install` whenever pods are regenerated.


---

## Usage

```js
import WalkMeSDK from '@walkme/react-native-sdk';

// Start the SDK
WalkMeSDK.start({
  systemGuid: 'YOUR_SYSTEM_GUID',
  environment: 'Production',       // optional, default: 'Production'
  dataCenter: 'prod',              // optional: 'prod' | 'eu' | 'us01' | 'eu01' | custom
  analyticsEnabled: true,          // optional, default: true
  localLogsEnabled: false,         // optional, default: false
});

// Stop the SDK
WalkMeSDK.stop();

// Set user ID
WalkMeSDK.setUserId('user-123');

// Set a custom variable
WalkMeSDK.setVariable('plan', 'premium');

// Set event user vars
WalkMeSDK.setEventUserVars({
  name: 'John Doe',
  role: 'admin',
  type: 'internal',
});

// Set display language
WalkMeSDK.setLanguage('en');

// Send a custom event
WalkMeSDK.sendEvent('button_clicked', { screen: 'home' });

// Start a specific item by ID
WalkMeSDK.startItemByID(42, null);

// Dismiss the current item (iOS only in this release)
WalkMeSDK.dismissItem();
```

---

## API Reference

| Method | Parameters | Description |
|---|---|---|
| `start(options)` | `WalkMeStartOptions` | Start the SDK |
| `stop()` | — | Stop the SDK |
| `startItemByID(itemId, deepLink?)` | `number`, `string?` | Launch a specific item |
| `dismissItem()` | — | Dismiss the active item |
| `setUserId(userId)` | `string \| null` | Set the end-user ID |
| `setVariable(key, value)` | `string`, `string \| null` | Set a segmentation variable |
| `setEventUserVars(vars)` | `WalkMeEventUserVars` | Set event user attributes |
| `setLanguage(language)` | `string` | Set the display language |
| `sendEvent(name, attributes?)` | `string`, `object?` | Send a custom event |

### `WalkMeStartOptions`

| Property | Type | Required | Default |
|---|---|---|---|
| `systemGuid` | `string` | ✅ | — |
| `environment` | `string` | | `'Production'` |
| `dataCenter` | `string` | | `'prod'` |
| `analyticsEnabled` | `boolean` | | `true` |
| `localLogsEnabled` | `boolean` | | `false` |

---

## Flavors

| Flavor | Android | iOS (`pod install`) | SDK |
|---|---|---|---|
| Standard | `missingDimensionStrategy 'walkmeMode', 'WalkMe'` | `pod install` (default) | WalkMe |
| Power Mode | `missingDimensionStrategy 'walkmeMode', 'WalkMeEditor'` | `WALKME_FLAVOR=WalkMeEditor pod install` | WalkMeEditor |

> **Both flavors require Lottie** on iOS — see [iOS Setup → Add Lottie](#3-add-lottie-required-for-both-flavors).

---

## License

UNLICENSED
