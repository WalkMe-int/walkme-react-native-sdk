require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# Flavor is selected at `pod install` time via the WALKME_FLAVOR env var,
# mirroring the Android `walkmeMode` build flavor. Defaults to standard "WalkMe".
#   WALKME_FLAVOR=WalkMeEditor pod install   # Power Mode
flavor = ENV["WALKME_FLAVOR"] == "WalkMeEditor" ? "WalkMeEditor" : "WalkMe"

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

      # The WalkMeEditor (Power Mode) framework depends on Lottie but does NOT
      # declare it (its Package.swift expects the host to provide Lottie).
      # We MUST declare it here for two reasons:
      #   1. Build time: WalkMeEditor.swiftinterface contains `import Lottie`,
      #      so the `Lottie` module must be in this pod's search path to compile,
      #      otherwise: "error: unable to resolve module dependency: 'Lottie'".
      #   2. Runtime: WalkMeEditor hard-links `@rpath/Lottie.framework/Lottie`.
      # The `lottie-ios` pod (module `Lottie`) under `use_frameworks! :linkage
      # => :dynamic` builds the correctly-named `Lottie.framework` AND is
      # auto-embedded by CocoaPods. A loose constraint reuses whatever Lottie
      # the app already has (e.g. via lottie-react-native) without conflict.
      s.dependency "lottie-ios", "~> 4.0"
    else
      spm_dependency(s,
        url: "https://github.com/WalkMe-int/walkme-ios-sdk",
        requirement: { kind: "upToNextMajorVersion", minimumVersion: "1.0.0" },
        products: ["WalkMe"]
      )
    end
  else
    raise "[walkme-react-native-sdk] React Native >= 0.75.0 is required: the SPM-only " \
          "WalkMe iOS SDK is integrated via the `spm_dependency` helper, which is unavailable " \
          "in your React Native version. Please upgrade to >= 0.75.0."
  end
end
