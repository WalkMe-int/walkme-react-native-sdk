# walkme_podfile.rb — CocoaPods post_install helpers for @walkme-mobile/react-native-sdk.
#
# The WalkMe iOS SDK is SPM-only and pulled in via `spm_dependency`, which leaves
# two integration gaps that can only be fixed from the consuming app's Podfile
# `post_install`, because both concern the *app* target rather than the pod:
#   1. CocoaPods links an SPM product to the Pods target but never embeds its
#      framework into the app bundle (app would crash at launch).
#   2. The xcframework's signature is collected once per build directory, and the
#      archive step then fails on the duplicate (release archives would fail).
# Rather than have every app copy/paste that logic, the bridge ships it here and
# the app just calls `walkme_post_install(installer)`.
#
# Usage in the app Podfile:
#
#   require Pod::Executable.execute_command('node', ['-p',
#     'require.resolve("@walkme-mobile/react-native-sdk/scripts/walkme_podfile.rb", {paths: [process.argv[1]]})',
#     __dir__]).strip
#
#   post_install do |installer|
#     react_native_post_install(installer, ...)
#     walkme_post_install(installer)
#   end

# Public entry point: applies every WalkMe integration fix. Safe to call once,
# after react_native_post_install.
def walkme_post_install(installer)
  walkme_embed_spm_frameworks(installer)
  walkme_dedupe_xcframework_signatures(installer)
end

# Embed the SPM frameworks into the app bundle.
# REQUIRED: the bridge hard-links @rpath/WalkMe*.framework, and the WalkMe SDK in
# turn hard-links @rpath/Lottie.framework/Lottie, but `spm_dependency` only links
# the SPM products to the Pods target — CocoaPods never copies them into the app
# bundle. Without this the app aborts at launch:
#   dyld: Library not loaded: @rpath/WalkMeEditor.framework/WalkMeEditor
#   dyld: Library not loaded: @rpath/Lottie.framework/Lottie
# (For WalkMe* the simulator happens to survive without it — it can load straight
# from the build products dir — but device cannot; Lottie fails on both.) This
# adds a build phase that rsyncs the frameworks in and codesigns them with the
# app's identity. Idempotent: the phase is found-or-created by name, so re-running
# `pod install` never duplicates it.
#
# Scoped narrowly on purpose: the phase is added only to embeddable targets
# (apps/extensions, not test/library targets), and the build script touches only
# the known product names (no wildcard that could match a host app's own
# framework). Only one WalkMe flavor is ever linked, so the other name is removed
# from the bundle if a stale copy lingers (clean flavor switches). Signing mirrors
# CocoaPods' own embed script: sign only when Xcode is actually signing, and
# preserve the framework's identifier/entitlements.
def walkme_embed_spm_frameworks(installer)
  embed_phase_name = '[WalkMe] Embed SPM Frameworks'
  embed_script = <<~SH
    set -euo pipefail
    [ -n "${BUILT_PRODUCTS_DIR:-}" ] || { echo "error: BUILT_PRODUCTS_DIR unset"; exit 1; }
    [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ] || exit 0
    DST="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    mkdir -p "$DST"
    for FW in WalkMe.framework WalkMeEditor.framework Lottie.framework; do
      SRC="${BUILT_PRODUCTS_DIR}/${FW}"
      if [ -d "$SRC" ]; then
        /usr/bin/rsync -a --delete "$SRC/" "$DST/$FW/"
        if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] \\
           && [ "${CODE_SIGNING_REQUIRED:-}" != "NO" ] \\
           && [ "${CODE_SIGNING_ALLOWED:-}" != "NO" ]; then
          /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \\
            --preserve-metadata=identifier,entitlements,flags "$DST/$FW"
        fi
      else
        rm -rf "$DST/$FW"
      fi
    done
  SH

  embeddable = [:application, :app_extension, :watch2_app, :watch2_extension]
  installer.aggregate_targets.each do |agg|
    project = agg.user_project
    next unless project
    agg.user_target_uuids.each do |uuid|
      native_target = project.objects_by_uuid[uuid]
      next unless native_target.respond_to?(:symbol_type)
      existing = native_target.shell_script_build_phases.select { |p| p.name == embed_phase_name }
      if embeddable.include?(native_target.symbol_type)
        phase = existing.first || native_target.new_shell_script_build_phase(embed_phase_name)
        phase.shell_script = embed_script
        phase.run_only_for_deployment_postprocessing = '0'
      else
        # Not an embeddable target (e.g. a unit-test bundle) — strip any phase a
        # previous version of this script may have added there.
        existing.each { |p| native_target.build_phases.delete(p) }
      end
    end
    project.save
  end
end

# Keep exactly ONE signature file per WalkMe/Lottie XCFramework in the build
# products directory, so archiving does not fail with:
#   "WalkMeEditor.xcframework-ios.signature" couldn't be copied to "Signatures"
#   because an item with the same name already exists.
#   (NSCocoaErrorDomain 516 / NSPOSIXErrorDomain 17)
#
# WHY (verified by archiving the test app on Xcode 26 and reading the build log):
# the WalkMe SDK and Lottie are SPM *binaryTarget* xcframeworks. For every build
# directory that consumes such an xcframework, Xcode plans a `SignatureCollection`
# task that writes `<Name>.xcframework-<platform>.signature` into that directory.
# CocoaPods gives each pod target its own `CONFIGURATION_BUILD_DIR`
# (`${PODS_CONFIGURATION_BUILD_DIR}/walkme-react-native-sdk`), which is a
# *subdirectory* of the shared archive build-products path, so the signature is
# collected twice — once for the app and once for the pod target:
#   Release-iphoneos/WalkMeEditor.xcframework-ios.signature
#   Release-iphoneos/walkme-react-native-sdk/WalkMeEditor.xcframework-ios.signature
# The archive action then FLATTENS every signature it finds under the build
# products path into a single `<archive>/Signatures/` folder, and the second copy
# collides with the first. Nothing about the host app causes this; it reproduces
# on a bare RN app that only adds this bridge. It is an Xcode bug (Apple
# FB12373687) that any CocoaPods library consuming an SPM binary target hits —
# e.g. maplibre-react-native ships the same workaround.
#
# Setting `ENABLE_SIGNATURE_AGGREGATION = NO` on the pod target does NOT help
# (tested): the collection tasks are planned regardless of that setting.
#
# So: after the app target is built, collapse the duplicates. The nested copy is
# removed when the top-level one exists, otherwise it is promoted to the top
# level — either way the archive still records one signature per framework, which
# is what the un-bugged behaviour would produce. Scoped to the framework names
# this bridge introduces, so a host app's own xcframework signatures are never
# touched. Runs late (last build phase) — long after the SignatureCollection
# tasks, which Xcode schedules at the very start of the build.
def walkme_dedupe_xcframework_signatures(installer)
  dedupe_phase_name = '[WalkMe] Dedupe XCFramework Signatures'
  dedupe_script = <<~SH
    set -euo pipefail
    [ -n "${BUILT_PRODUCTS_DIR:-}" ] || exit 0
    for SIG in "${BUILT_PRODUCTS_DIR}"/*/*.xcframework-*.signature; do
      [ -e "$SIG" ] || continue
      BASE="$(basename "$SIG")"
      case "$BASE" in
        WalkMe.xcframework-*|WalkMeEditor.xcframework-*|Lottie.xcframework-*) ;;
        *) continue ;;
      esac
      TOP="${BUILT_PRODUCTS_DIR}/$BASE"
      if [ -e "$TOP" ]; then
        rm -f "$SIG"
      else
        mv "$SIG" "$TOP"
      fi
    done
  SH

  embeddable = [:application, :app_extension, :watch2_app, :watch2_extension]
  installer.aggregate_targets.each do |agg|
    project = agg.user_project
    next unless project
    agg.user_target_uuids.each do |uuid|
      native_target = project.objects_by_uuid[uuid]
      next unless native_target.respond_to?(:symbol_type)
      existing = native_target.shell_script_build_phases.select { |p| p.name == dedupe_phase_name }
      if embeddable.include?(native_target.symbol_type)
        phase = existing.first || native_target.new_shell_script_build_phase(dedupe_phase_name)
        phase.shell_script = dedupe_script
        phase.run_only_for_deployment_postprocessing = '0'
      else
        existing.each { |p| native_target.build_phases.delete(p) }
      end
    end
    project.save
  end
end
