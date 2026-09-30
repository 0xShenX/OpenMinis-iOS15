# iOS 15.4 compatibility status

This branch is a partial port, NOT a verified iOS 15 build. No IPA has been
produced or installed. The local development host is Windows and has no
Xcode or Swift compiler. Static source tests are not compile tests.

## Implemented

- Main app, Share Extension, project defaults and test targets use iOS 15.4.
- Chat's four hosting configuration sites dispatch to native
  UIHostingConfiguration on iOS 16+, or a retained UIHostingController-based
  UIContentView on iOS 15. The original message views remain intact.
- rclone device and simulator native slices target iOS 15.4.
- Manual-only `.github/workflows/ios-trollstore.yml` uses a standard macOS
  runner, read-only repository permissions, no dependency cache, recursive
  submodules, Go 1.25, Homebrew prerequisites and the provider config template.
  It builds LAME, FFmpeg, iSH, Alpine rootfs and rclone before archiving.
- The workflow archives unsigned, then ad-hoc signs Payload/Minis.app and the
  retained share extension with declared capabilities before packaging. It retains the artifact
  for three days. It strips the iOS 16-only Widget and replicated File Provider
  extensions from this IPA only. Their targets and embedding remain available
  in normal modern-OS builds.

## Known blockers

The workflow is expected to fail compilation until these are implemented:

- NavigationStack, NavigationPath, NavigationSplitView and value-based
  destinations in ContentView and settings/chat sheets need genuine iOS 15
  navigation state and deep-link handling, not text substitutions.
- PHPicker adapters replace SwiftUI PhotosPickerItem in chat and Soul settings.
  Chat inserts all placeholders before concurrent provider loads, preserves
  failed selections, resolves chips in-place and cancels Progress on disappearance.
  Device testing of cancellation, large videos and iCloud-backed photos remains required.
- SwiftUI Layout implementations and iOS 16 presentation/toolbar/scroll
  modifiers need availability wrappers or equivalent older-OS layouts.
- AppIntents, ActivityKit, WeatherKit and app-side NSFileProviderManager APIs
  need a full availability audit. Keeping newer extension deployment targets
  does not automatically guard calls from the main app.
- Swift packages, including the binary RealTimeCutVADLibrary, need resolved
  manifest and Mach-O minimum-OS inspection on macOS. Lowering the main target
  does not lower a prebuilt binary's minimum system version.

## Dependency minimum audit

The repository does not contain a Swift Package manifest or a committed
`Package.resolved` for the iOS target. The RealTimeCutVADLibrary is consumed as
a prebuilt binary, so its minimum iOS version cannot be established from this
Windows checkout. A macOS/Xcode audit is required before release:

- Run `xcodebuild -resolvePackageDependencies` for the archive workspace and
  inspect the resolved package graph for deployment requirements.
- Inspect every vendored `.framework`/`.xcframework` slice with `otool -l` and
  verify `LC_BUILD_VERSION` (or `LC_VERSION_MIN_IPHONEOS`) is no higher than
  iOS 15.4 for app-linked slices.
- Treat an incompatible VAD slice as a release blocker; do not lower the app
  deployment target and assume the binary became iOS 15-compatible.
- Keep the ActivityKit widget and replicated FileProvider extension at their
  modern deployment targets; the iOS 15 packaging workflow omits
  those extensions, while the main app now skips their app-side APIs at runtime.
- LegacyHostingContentView requires device tests for sizing, reuse, controller
  containment, context menus, rotation and streaming. No Swift typecheck has
  been performed.
- Packaging has not been tested with TrollStore. Required App Group,
  iCloud/Keychain entitlements and provider customization behavior need device
  verification; no provisioning certificate or account secrets are bundled.

## TrollStore signing evidence and CI diagnostics

Upstream [RootHelper/main.m](https://github.com/opa334/TrollStore/blob/main/RootHelper/main.m),
`signApp` (lines 552-710 at inspection), reads embedded entitlements, supplies
fallback entitlements only when the main binary has none, then signs recursively
and applies its CoreTrust bypass. `installApp` calls `signApp` (around line 897).
Thus an unsigned IPA is not inherently uninstallable, but its declared App Group
capability would be lost: fallback signing does not reconstruct our source plist.

CI ad-hoc signatures embed the original app/share capability plists, with explicit
TrollStore-local application/team identifiers and a shared, app-scoped Keychain
group (`TROLLTROLL.com.openminis.app`). Existing source identity/keychain entries
take precedence. This does not grant Apple provisioning or server authorization,
does not import App Store Keychain data, and makes no claim that CloudKit, APNs,
HealthKit or other restricted services work. No broad Keychain wildcard, private
sandbox entitlement or pre-applied bypass is added. TrollStore performs its own
installation signing; compatibility still needs a supported-device install test.

The manual standard `macos-15` workflow resolves packages, records build settings
and parses Swift before the expensive native build. Parsing is syntax-only, not
a replacement for SDK availability/type checking. Native dependencies are still
required before a real archive, so there is no fake dependency/link bypass.
Every build phase tees output to diagnostics; `always()` uploads these logs,
the archive xcresult, and Package.resolved even after a failure. Successful
packaging verifies signatures, reads back embedded entitlements, records Mach-O
build versions and tests the IPA ZIP. Mach-O minima need human review before release.

## Local checks

Run from the repository root:

```sh
python tests/ios15_compatibility_test.py
bash -n deps/build_rclone_ios.sh
git diff --check
```

These checks cover source wiring, deployment configuration and workflow
presence. They deliberately do not claim complete API availability or runtime
correctness. A successful macOS archive and iOS 15.4.1 device installation are
mandatory before labeling this fork compatible.
