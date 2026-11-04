# Intel compatibility development checkpoint — 2026-11-04

## Scope

Maintainer requested Intel support for Macs from approximately 2017–2018;
Catalina support is explicitly excluded. This is a hardware coverage goal,
not a guarantee covering every model or its factory-installed macOS.
No website, public installer, signing credential or phrase schema changes.

## Source audited

Base: codex/macos-guided-setup at 94ecf75 (version 0.4.3, bundle build 6).
Package.swift and Info.plist declare macOS 13.0. The Swift/AppKit shell
launches a bundled self-contained net10.0 CommonCopy.DesktopBridge helper.
The existing build script accepts x86_64/osx-x64, but CI only built arm64.
The DMG script incorrectly hardcoded arm64 in its output filename.

SwiftUI Table, dismiss and other post-Catalina APIs block simply reducing
the deployment target to Catalina. The runtime's vendor support matrix
also excludes Catalina. No deployment targets have been lowered.

## Changes prepared

- Separate native arm64 and x86_64 CI jobs on macos-15 and macos-15-intel.
- Each architecture runs core tests, Swift tests, packaged helper protocol
  tests, installed-path/UI launch smoke checks and DMG install/launch checks.
- Architecture-specific artifact names avoid collisions and misleading labels.
- Verify the Swift executable and .NET helper contain the expected architecture.
- Record executable load commands and the test host for compatibility review.

## Validation and limitations

Local shell syntax, workflow YAML structure and diff checks are available.
macOS compilation, execution, DMG packaging and Swift/.NET tests require
Mac runners; they have NOT yet run for this change. Developer ID signing,
notarization and manual Accessibility/paste/capture acceptance remain required.
An Intel build passing on Sequoia does not establish Monterey, Ventura or
Sonoma compatibility. The selected latest .NET 10 patch must be evaluated
against each promised OS; a self-contained package still depends on its OS.

## Model-year caveat

Apple lists Monterey as the newest OS for the 2017 MacBook Air and Sonoma
for the 2018 MacBook Air. Other 2017–2018 models have different ceilings.
Keep download labels architecture + verified OS range. Do not state
“all 2017 Macs”, “legacy supported” or “macOS 13+ verified” from build settings.

## References

- https://support.apple.com/en-us/102869
- https://github.com/dotnet/core/blob/main/release-notes/10.0/supported-os.md
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners

## Next gate

Publish the prepared development branch and run CI after maintainer approval,
then inspect minimum binary requirements and test candidate older OS releases.
Only add a downloadable Intel/Legacy option after compatible signed artifacts
and acceptance results exist. This checkpoint does not authorize a release.
