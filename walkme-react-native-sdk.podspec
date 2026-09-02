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
# Read the consuming app's package.json once; both the flavor and the optional
# SDK-version pin are resolved declaratively from its `walkme` block.
app_root = Pod::Config.instance.installation_root&.parent
app_pkg  = app_root ? (JSON.parse(File.read(File.join(app_root.to_s, "package.json"))) rescue {}) : {}

walkme_mode_raw =
  ENV["WALKME_FLAVOR"] ||
  app_pkg.dig("walkme", "walkmeMode") ||
  "WalkMe"

flavor =
  case walkme_mode_raw.to_s.downcase
  when "walkmeeditor" then "WalkMeEditor"
  when "walkme"       then "WalkMe"
  else
    raise "[walkme-react-native-sdk] Unknown walkmeMode #{walkme_mode_raw.inspect}. " \
          "Set package.json \"walkme\": { \"walkmeMode\": \"WalkMe\" } or \"WalkMeEditor\" " \
          "(or the WALKME_FLAVOR env var)."
  end

# Optional WalkMe iOS SDK version pin. Resolution: WALKME_SDK_VERSION env
# (one-off override) → app package.json `walkme.sdkVersion` → unset.
#   "walkme": { "walkmeMode": "WalkMeEditor", "sdkVersion": "1.2.0" }
# When UNSET the bridge always pulls the latest published SDK release (any
# minor/major) at `pod install` time. When SET it pins that exact version.
# Either way the host is responsible for choosing a version the bridge's code
# supports. Applied identically to both flavors.
walkme_sdk_min_version = "1.1.0"
walkme_sdk_version =
  ENV["WALKME_SDK_VERSION"] ||
  app_pkg.dig("walkme", "sdkVersion")

spm_requirement =
  if walkme_sdk_version && !walkme_sdk_version.to_s.strip.empty?
    { kind: "exactVersion", version: walkme_sdk_version.to_s.strip }
  else
    { kind: "versionRange", minimumVersion: walkme_sdk_min_version, maximumVersion: "10000.0.0" }
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
  #
  # NOTE: `spm_dependency` does NOT require `use_frameworks! :linkage => :dynamic`.
  # RN's helper logs a warning under static linking, but it is only advisory —
  # verified on device/simulator that with default (static) pods the Swift
  # autolink record still resolves the SPM framework and the app links, launches
  # and runs. Consumers may keep their existing pod linkage.
  #
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
        requirement: spm_requirement,
        products: ["WalkMeEditor"]
      )
    else
      spm_dependency(s,
        url: "https://github.com/WalkMe-int/walkme-ios-sdk",
        requirement: spm_requirement,
        products: ["WalkMe"]
      )
    end

    # BOTH WalkMe SDK flavors hard-link @rpath/Lottie.framework/Lottie at runtime
    # but do NOT declare Lottie (their Package.swift expects the host app to
    # provide it), and their .swiftinterface contains `import Lottie`, so the
    # module must also be on this pod's search path to compile.
    #
    # `lottie-spm` is Airbnb's official SPM distribution of the PREBUILT *dynamic*
    # `Lottie.xcframework` (framework and binary are both literally named
    # `Lottie`), so it satisfies that load command exactly. Preferred over:
    #   - the `lottie-ios` CocoaPods pod, which only yields a dynamic
    #     `Lottie.framework` under `use_frameworks! :linkage => :dynamic`. That
    #     single requirement is what forced dynamic frameworks app-wide on every
    #     consumer. It also builds from source WITHOUT library evolution, so it
    #     needed a `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` post_install patch to
    #     match the prebuilt WalkMe frameworks' resilient ABI.
    #   - lottie-ios's own SPM products (`Lottie` is static; `Lottie-Dynamic`
    #     produces the wrong framework name).
    #   - a hand-rolled binaryTarget (pins one exact version + checksum and
    #     cannot dedupe with a host app's own Lottie).
    # As a shared SPM package it unifies with a host app that also uses
    # lottie-spm. Same choice as the sibling walkme-capacitor plugin.
    spm_dependency(s,
      url: "https://github.com/airbnb/lottie-spm.git",
      requirement: { kind: "upToNextMajorVersion", minimumVersion: "4.6.0" },
      products: ["Lottie"]
    )
  else
    raise "[walkme-react-native-sdk] React Native >= 0.75.0 is required: the SPM-only " \
          "WalkMe iOS SDK is integrated via the `spm_dependency` helper, which is unavailable " \
          "in your React Native version. Please upgrade to >= 0.75.0."
  end
end
