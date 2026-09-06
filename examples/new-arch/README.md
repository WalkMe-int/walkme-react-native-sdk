# New Arch — WalkMe React Native example

React Native **0.85.3** on the **New Architecture** (bridgeless, TurboModules).
The bridge resolves through `TurboModuleRegistry`; the app header prints the
architecture the JavaScript runtime actually landed on, so you can confirm it.

| | |
|---|---|
| React Native | 0.85.3 |
| Architecture | New (bridgeless) — `newArchEnabled=true` in `android/gradle.properties`, `RCT_NEW_ARCH_ENABLED` on iOS |
| WalkMe flavor | `WalkMeEditor` (Power Mode) — `walkme.walkmeMode` in `package.json` |
| Android package | `com.walkmeexample` |
| iOS scheme | `WalkMeExample` |

The Legacy Architecture counterpart is [`../legacy`](../legacy). Both apps share
the same `App.tsx`, which is the point: nothing in it is architecture-aware.

## The SDK comes from this checkout

`package.json` depends on the bridge as `file:../..`, so `npm install` links the
repository root rather than downloading a published version. The example always
exercises the code on your branch — edit `index.js` or the native sources and
rebuild, no packing or publishing step.

`metro.config.js` carries the two adjustments that link needs: the repository
root is added to `watchFolders`, and the root's own `node_modules` is blocked so
Metro can never load the SDK's dev copy of React Native next to this app's.

## Prerequisites

- **Node ≥ 20.19.4.** Older versions fail during JS bundling with
  `configs.toReversed is not a function`.
- **`ANDROID_HOME`** pointing at your Android SDK, or `sdk.dir` in
  `android/local.properties`.
- For iOS: Xcode, and CocoaPods (`bundle install`, then `bundle exec pod install`
  in `ios/`).

```sh
npm install
```

## Run it

```sh
npm start          # Metro
npm run android    # or: npm run ios
```

## Build an APK

Every APK this project produces is **standalone**: the JS bundle is compiled in
for all variants and the app never looks for a Metro dev server, so the file
runs on any device without anything else running on your machine.

```sh
./android/gradlew -p android assembleDebug     # android/app/build/outputs/apk/debug/app-debug.apk
./android/gradlew -p android assembleRelease   # android/app/build/outputs/apk/release/app-release.apk
```

Pass `-PuseDevServer=true` when you want the normal Metro / Fast Refresh
workflow back — that build expects `npm start` to be running.

Note that the Gradle daemon caches the environment it was started with: after
changing `PATH` (a different Node, for instance) run `./android/gradlew -p
android --stop` first, or the old value is what the build actually uses.
