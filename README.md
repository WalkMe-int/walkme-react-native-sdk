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

### 1. Install CocoaPods dependencies

```sh
cd ios && pod install
```

### 2. Add the bridge package in Xcode

- Open your `.xcworkspace` in Xcode
- **File → Add Package Dependencies**
- Add the bridge package URL (or local path during development)
- Select the product that matches your flavor:
  - **`RNWalkMeSdkWalkMe`** — standard SDK
  - **`RNWalkMeSdkWalkMeEditor`** — Power Mode SDK
- Add to your app target

The WalkMe iOS SDK is pulled in automatically as a transitive SPM dependency.

> No `AppDelegate` changes are needed — `RCT_EXTERN_MODULE` auto-registers the native module.

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

| Flavor | Android | iOS SPM product | SDK |
|---|---|---|---|
| Standard | `missingDimensionStrategy 'walkmeMode', 'WalkMe'` | `RNWalkMeSdkWalkMe` | WalkMe |
| Power Mode | `missingDimensionStrategy 'walkmeMode', 'WalkMeEditor'` | `RNWalkMeSdkWalkMeEditor` | WalkMeEditor |

---

## License

UNLICENSED
