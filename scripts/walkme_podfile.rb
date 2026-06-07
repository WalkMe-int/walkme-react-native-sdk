# walkme_podfile.rb — CocoaPods post_install helpers for @walkme/react-native-sdk.
#
# The WalkMe iOS SDK is SPM-only and pulled in via `spm_dependency`, which leaves
# two integration gaps that can only be fixed from the consuming app's Podfile
# `post_install` (CocoaPods does not let a podspec configure another pod's target
# or embed an SPM framework). Rather than have every app copy/paste that logic,
# the bridge ships it here and the app just calls `walkme_post_install(installer)`.
#
# Usage in the app Podfile:
#
#   require Pod::Executable.execute_command('node', ['-p',
#     'require.resolve("@walkme/react-native-sdk/scripts/walkme_podfile.rb", {paths: [process.argv[1]]})',
#     __dir__]).strip
#
#   post_install do |installer|
#     react_native_post_install(installer, ...)
#     walkme_post_install(installer)
#   end

# Public entry point: applies every WalkMe integration fix. Safe to call once,
# after react_native_post_install.
def walkme_post_install(installer)
  walkme_fix_lottie_abi(installer)
  walkme_embed_spm_frameworks(installer)
end

# Fix 1 — Lottie ABI.
# The prebuilt WalkMe* frameworks are compiled against a library-evolution
# (resilient) build of Lottie, so they link Lottie's resilient entry points
# (e.g. _$s6Lottie0A8LoopModeO4loopyA2CmFWC = LottieLoopMode.loop). The
# `lottie-ios` pod builds Lottie from source WITHOUT library evolution, so those
# symbols are absent → dyld launch crash even though Lottie.framework is embedded.
# Building lottie-ios with BUILD_LIBRARY_FOR_DISTRIBUTION=YES produces the
# matching resilient ABI. A podspec can't set this on a pod it doesn't own, so it
# has to happen here.
def walkme_fix_lottie_abi(installer)
  installer.pods_project.targets.each do |target|
    next unless target.name == 'lottie-ios'
    target.build_configurations.each do |config|
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end

# Fix 2 — Embed the WalkMe SPM framework into the app bundle.
# REQUIRED for device/release builds: walkme_react_native_sdk.framework hard-links
# @rpath/WalkMe*.framework, but `spm_dependency` only links the SPM product to the
# Pods target — CocoaPods never copies it into the app bundle. On device dyld only
# searches the app bundle, so without this the app aborts at launch:
#   dyld: Library not loaded: @rpath/WalkMeEditor.framework/WalkMeEditor
# (Simulator happens to work without it — it can load straight from the build
# products dir — but device cannot.) This adds a build phase that rsyncs the
# framework in and codesigns it with the app's identity. Idempotent: the phase is
# found-or-created by name, so re-running `pod install` never duplicates it.
def walkme_embed_spm_frameworks(installer)
  embed_phase_name = '[WalkMe] Embed SPM Frameworks'
  embed_script = <<~SH
    set -e
    DST="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    mkdir -p "$DST"
    for SRC in "${BUILT_PRODUCTS_DIR}"/WalkMe*.framework; do
      [ -d "$SRC" ] || continue
      FW="$(basename "$SRC")"
      /usr/bin/rsync -a --delete "$SRC/" "$DST/$FW/"
      /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$DST/$FW"
    done
  SH

  installer.aggregate_targets.each do |agg|
    project = agg.user_project
    next unless project
    agg.user_target_uuids.each do |uuid|
      native_target = project.objects_by_uuid[uuid]
      next unless native_target.respond_to?(:shell_script_build_phases)
      phase = native_target.shell_script_build_phases.find { |p| p.name == embed_phase_name }
      phase ||= native_target.new_shell_script_build_phase(embed_phase_name)
      phase.shell_script = embed_script
      phase.run_only_for_deployment_postprocessing = '0'
    end
    project.save
  end
end
