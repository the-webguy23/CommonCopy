# CommonCopy website

This folder contains the static CommonCopy download website. It has no package manager, build step, cookies, analytics, external fonts, or runtime dependencies.

## Preview locally

Open `dist/index.html` in a browser. All pages and navigation work directly from the filesystem.

## Add release downloads

After creating the Windows release files under `artifacts/release`, run this from the repository root in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\website\scripts\sync-release.ps1
```

The script copies these files into `dist/downloads`:

- `CommonCopy-Setup-x64.exe`
- `CommonCopy-Portable-x64.zip`
- `SHA256SUMS.txt`

## Current continuation (2026-10-16)

The existing three-page site is retained, with the current Warm Editorial / copper
palette, a compact-menu example, Windows/macOS copy, and explicit coming-soon
release controls. macOS core workflows and automatic dismissal after Save passed
maintainer testing; the new compact Windows menu still needs device acceptance.
No private test binaries are exposed by this website.

Advertising is approved for the website only. A third-party ad-space reseller is
planned but has not been selected or connected. Do not add an advertising script
until its integration and privacy information are prepared. The desktop app stays
ad-free. The interactive example uses temporary browser memory only.

Static hosting preview uses a Sites source snapshot of this folder. Keep the
repository's `website/` folder as the project source, and synchronize changes
before deployment. No public launch, domain purchase, paid provider enrollment,
or application release is implied by publishing the owner-private preview.

## Before public launch

- Verify public source availability before enabling repository links.
- Confirm both platform versions and release notes; enable download links only for approved public binaries.
- Select and integrate the website ad reseller, keeping ads clearly separate from download controls.
- Update privacy information and any required choices before advertising is enabled.
- Test every download from the deployed site.
- Add privacy-conscious aggregate analytics only after a separate review.

Public launch is deferred pending approved installers and compatibility testing. An owner-private website preview may be deployed for review.
