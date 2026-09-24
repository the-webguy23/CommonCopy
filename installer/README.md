# Installer

`CommonCopy.iss` is an initial Inno Setup definition for an x64 self-contained publish.

1. Publish the app to `artifacts/publish/win-x64` using the command in the root README.
2. Install Inno Setup 6.
3. Compile `installer/CommonCopy.iss`.
4. Test install, upgrade, optional startup, and uninstall on clean Windows 10 and Windows 11 virtual machines.

Code signing is intentionally not configured. Never commit a signing certificate or password.

The repository-level `scripts/build-local-release.ps1` script performs these steps automatically and copies the finished installer, portable ZIP, and checksums into `artifacts/release` and the local website.
