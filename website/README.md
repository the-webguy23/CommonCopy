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

## Before public launch

- Replace the disabled GitHub labels with the public repository URL.
- Confirm the displayed version and release notes.
- Add a real sponsorship contact method or payment link only after it is ready.
- Test every download from the deployed site.
- Add privacy-conscious aggregate analytics only after a separate review.

Publishing is intentionally deferred while GitHub access is unavailable.
