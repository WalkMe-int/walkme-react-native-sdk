require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Flavor selection. Named `walkmeMode` to match the Android flavor dimension
# (`flavorDimensions 'walkmeMode'` / `missingDimensionStrategy 'walkmeMode', …`),
# so the mental model is identical across platforms. Read declaratively from the
# consuming app's package.json:
#   "walkme": { "walkmeMode": "WalkMeEditor" }   // Power Mode
# so a plain `pod install` always picks the right flavor — no per-invocation env
# var that silently falls back to base WalkMe if forgotten, and it survives
# IDE/CI-triggered installs. The WALKME_FLAVOR env var still works as an override.
#
# This podspec lives in node_modules; during `pod install` CocoaPods'
# installation_root points at the app's `ios/` dir, so its parent is the app
# root — hoisting-safe regardless of where node_modules placed this package.
#
# Resolution: WALKME_FLAVOR env var (override) → app package.json `walkme.walkmeMode`
# → default "WalkMe". Matching is case-insensitive, and an UNRECOGNIZED non-empty
# value raises at `pod install` rather than silently building the wrong flavor
# (e.g. a typo like "Editor" must not quietly fall back to base WalkMe).
walkme_mode_raw =
  ENV["WALKME_FLAVOR"] ||
  begin
    app_root = Pod::Config.instance.installation_root&.parent
    app_pkg  = app_root ? (JSON.parse(File.read(File.join(app_root.to_s, "package.json"))) rescue {}) : {}
    app_pkg.dig("walkme", "walkmeMode")
  end || "WalkMe"

flavor =
  case walkme_mode_raw.to_s.downcase
  when "walkmeeditor" then "WalkMeEditor"
  when "walkme"       then "WalkMe"
  else
    raise "[walkme-react-native-sdk] Unknown walkmeMode #{walkme_mode_raw.inspect}. " \
          "Set package.json \"walkme\": { \"walkmeMode\": \"WalkMe\" } or \"WalkMeEditor\" " \
          "(or the WALKME_FLAVOR env var)."
  end

Pod::Spec.new do |s|
  s.name            = "walkme-react-native-sdk"
  s.version         = package["version"]
  s.summary         = package["description"]
  s.homepage        = "https://github.com/WalkMe-int/walkme-react-native-sdk"
  s.license         = package["license"]
  s.authors         = { "WalkMe" => "support@walkme.com" }
  s.platforms       = { :ios => "14.0" }
  s.source          = { :git => "https://github.com/WalkMe-int/walkme-react-native-sdk.git", :tag => "#{s.version}" }
  s.swift_version   = "5.9"

  # Only the selected flavor folder is compiled (shared bridge + module + flavor adapter).
  s.source_files    = "ios/Sources/#{flavor}/**/*.{h,m,mm,swift}"

  # Pulls in React-Core (and New Architecture deps when enabled). Requires RN >= 0.71.
  install_modules_dependencies(s)

  # The WalkMe iOS SDK is distributed ONLY via Swift Package Manager.
  # `spm_dependency` is what lets a CocoaPods-autolinked library consume an
  # SPM-only dependency — it requires React Native >= 0.75.0.
  # NOTE: consumers must set `use_frameworks! :linkage => :dynamic` in their Podfile.
  # `spm_dependency` is defined as a top-level method in React Native's
  # `react_native_pods.rb` (RN >= 0.75), which makes it a *private* method on
  # Object. `respond_to?` therefore needs `include_private: true` to see it.
  if respond_to?(:spm_dependency, true)
    # Each flavor pulls ONLY its own SDK, mirroring the Android `walkmeMode`
    # flavors. The WalkMe and WalkMeEditor frameworks ship overlapping
    # Objective-C classes, so linking both would risk duplicate-symbol /
    # runtime conflicts. The Editor flavor's provider imports `WalkMeEditor`
    # exclusively (it re-declares WalkMeStartOptions / WalkMeDataCenter), so the
    # base WalkMe SDK is not needed there.
    if flavor == "WalkMeEditor"
      spm_dependency(s,
        url: "https://github.com/WalkMe-int/walkme-ios-sdk-editor",
        requirement: { kind: "upToNextMajorVersion", minimumVersion: "1.0.0" },
        products: ["WalkMeEditor"]
      )
    else
      spm_dependency(s,
        url: "https://github.com/WalkMe-int/walkme-ios-sdk",
        requirement: { kind: "upToNextMajorVersion", minimumVersion: "1.0.0" },
        products: ["WalkMe"]
      )
    end

    # BOTH WalkMe SDK flavors depend on Lottie at runtime but do NOT declare it
    # (their Package.swift expects the host app to provide Lottie). We MUST declare
    # it here for two reasons:
    #   1. Build time: the WalkMe*.swiftinterface contains `import Lottie`, so the
    #      `Lottie` module must be on this pod's search path to compile, otherwise:
    #      "error: unable to resolve module dependency: 'Lottie'".
    #   2. Runtime: the WalkMe framework hard-links `@rpath/Lottie.framework/Lottie`.
    # The `lottie-ios` pod (module `Lottie`) under `use_frameworks! :linkage =>
    # :dynamic` builds the correctly-named `Lottie.framework` AND is auto-embedded
    # by CocoaPods. A loose constraint reuses whatever Lottie the app already has
    # (e.g. via lottie-react-native) without conflict.
    #
    # NOTE: the consuming app must build lottie-ios with library evolution
    # (BUILD_LIBRARY_FOR_DISTRIBUTION=YES) so its ABI matches the prebuilt WalkMe
    # frameworks, otherwise: dyld "Symbol not found: ...LottieLoopMode.loop" at
    # launch. See README "iOS Setup".
    # Pinned to the exact Lottie version the prebuilt WalkMe* frameworks were
    # compiled against. The app no longer needs lottie-react-native; this brings
    # Lottie in via the bridge. An app that uses Lottie itself must match 4.6.0.
    s.dependency "lottie-ios", "4.6.0"
  else
    raise "[walkme-react-native-sdk] React Native >= 0.75.0 is required: the SPM-only " \
          "WalkMe iOS SDK is integrated via the `spm_dependency` helper, which is unavailable " \
          "in your React Native version. Please upgrade to >= 0.75.0."
  end
end
