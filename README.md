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
> introduced in RN 0.75. `spm_dependency` requires **dynamic frameworks**.

The bridge does the heavy lifting: it pulls the correct WalkMe SPM package **and** the
matching [Lottie](https://github.com/airbnb/lottie-ios) dependency it needs, and it ships
the required CocoaPods `post_install` logic as a helper you call from your Podfile. You do
**not** install `lottie-react-native`, you do **not** set any environment variable, and you
do **not** copy any framework-embedding script.

### 1. Select the flavor in `package.json`

Add a `walkme` block to your **app's** `package.json` (a sibling of `dependencies`):

```json
{
  "dependencies": {
    "@walkme/react-native-sdk": "..."
  },
  "walkme": {
    "iosFlavor": "WalkMeEditor"
  }
}
```

| `iosFlavor` value | SDK pulled |
|---|---|
| omitted, or `"WalkMe"` | standard **WalkMe** (default) |
| `"WalkMeEditor"` | Power Mode (**WalkMeEditor**) |

It's read at `pod install` time, is **case-insensitive**, and an unrecognized value
(e.g. a typo like `"Editor"`) **fails the install with a clear error** — so you never
silently build the wrong SDK. This mirrors the Android `walkmeMode` flavor: declare it
once, in source control.

### 2. Wire up the `ios/Podfile`

Three additions, alongside what RN's template already generates:

```ruby
# (a) At the top, next to the react-native require — load the bridge's CocoaPods
#     helpers. Resolved via node so it's correct regardless of node_modules layout
#     (hoisting / Yarn or npm workspaces / pnpm), the same way RN resolves its own.
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "@walkme/react-native-sdk/scripts/walkme_podfile.rb",
    {paths: [process.argv[1]]},
  )', __dir__]).strip

# (b) The bridge requires dynamic frameworks (spm_dependency mandates this).
use_frameworks! :linkage => :dynamic

target 'YourApp' do
  config = use_native_modules!
  use_react_native!(:path => config[:reactNativePath])

  post_install do |installer|
    react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => false)

    # (c) Apply WalkMe's required build fixes: Lottie ABI + WalkMe SPM framework embed.
    #     See "How the iOS integration scripts work" below.
    walkme_post_install(installer)
  end
end
```

> No `AppDelegate` changes are needed — `RCT_EXTERN_MODULE` auto-registers the native module.

### 3. Install pods & run

```sh
npm install
cd ios && pod install && cd ..
npx react-native run-ios
```

A plain `pod install` selects the flavor from `package.json` and pulls Lottie via the
bridge. To switch flavors later, edit `walkme.iosFlavor` and re-run `pod install`.

> **CI / one-off override:** the `WALKME_FLAVOR` environment variable still works and
> takes precedence over `package.json`, e.g. `WALKME_FLAVOR=WalkMeEditor pod install`.

---

## How the iOS integration scripts work

The bridge ships **`scripts/walkme_podfile.rb`** inside the npm package and exposes one
public function — `walkme_post_install(installer)` — that you call from your Podfile's
`post_install`. It performs two fixes that **CocoaPods cannot do from a podspec alone**: a
podspec can only configure its *own* pod target, not another pod (`lottie-ios`) or the app
bundle. Keeping the logic in the bridge means it's version-locked to the SDK and you never
copy/paste it.

### `walkme_fix_lottie_abi(installer)` — Lottie ABI
Sets `BUILD_LIBRARY_FOR_DISTRIBUTION = YES` on the `lottie-ios` pod. The prebuilt WalkMe
frameworks are compiled against a **library-evolution (resilient)** build of Lottie, so they
link Lottie's resilient symbols (e.g. `LottieLoopMode.loop`). The `lottie-ios` pod builds
from source *without* library evolution, so those symbols are absent and the app crashes at
launch with `dyld: Symbol not found: …LottieLoopMode.loop` — even though `Lottie.framework`
is embedded. Building Lottie with library evolution produces the matching ABI.

### `walkme_embed_spm_frameworks(installer)` — embed the WalkMe framework
Rsyncs and codesigns the WalkMe SPM framework into the app bundle. `spm_dependency` links
the framework to the Pods target but never embeds it in the app. On a **physical device**
dyld only searches the app bundle, so without this the app aborts at launch with
`dyld: Library not loaded: @rpath/WalkMeEditor.framework`. **Required for device/release
builds.** (The simulator can load the framework from the build folder, so it happens to run
without embedding — a device cannot.) The build phase is found-or-created by name, so
re-running `pod install` never duplicates it.

### Why Lottie comes from the bridge
The podspec declares `lottie-ios`, **pinned to the exact version the WalkMe frameworks were
built against**, so a single standalone Lottie pod is shared. If your app *also* uses Lottie
(e.g. via `lottie-react-native`), pin it to that same version so CocoaPods resolves one
`Lottie.framework` — mismatched versions will error rather than ship two copies.

> The only thing CocoaPods won't let the bridge do automatically is inject the
> `post_install` call itself (that needs a CocoaPods plugin). Hence the single
> `walkme_post_install(installer)` line in your Podfile.


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

| Flavor | Android (`android/app/build.gradle`) | iOS (`package.json`) | SDK |
|---|---|---|---|
| Standard | `missingDimensionStrategy 'walkmeMode', 'WalkMe'` | `"walkme": { "iosFlavor": "WalkMe" }` (or omit) | WalkMe |
| Power Mode | `missingDimensionStrategy 'walkmeMode', 'WalkMeEditor'` | `"walkme": { "iosFlavor": "WalkMeEditor" }` | WalkMeEditor |

> On iOS, both flavors need Lottie — but the bridge supplies it automatically (see
> [How the iOS integration scripts work](#how-the-ios-integration-scripts-work)). No
> `lottie-react-native` install is required.

---

## License

UNLICENSED
