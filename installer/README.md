# Windows setup

The normal download is `CommonCopy-Setup-x64.exe`: one offline installer for the current Windows user, with the approved vector logo, native text, extraction progress, MIT notice, and an Open CommonCopy finish action. No administrator access or separate .NET download is required.

Program files go in `%LOCALAPPDATA%\Programs\CommonCopy`. The Start menu shortcut and Windows Settings uninstall entry are installed automatically. Start-with-Windows remains an application setting, preserving the user's existing choice.

The installed `Notices` directory keeps the license and third-party notices from the exact .NET and Windows Desktop runtime packs used in the build. These required text notices stay inside the installation, alongside offline Help and CommonCopy's MIT license.

Phrase data stays in `%LOCALAPPDATA%\CommonCopy`. Setup never installs into, deletes, or rewrites this directory. Exit the tray application before updating or uninstalling; closing its manager only hides it. Uninstall removes the program, shortcut, and CommonCopy startup entry, keeping the library and backups for reinstall.

On Windows, install .NET SDK 10 and Inno Setup 6, then run `powershell -File scripts/build-local-release.ps1` from the repository root. This checks the application, renders branding from the approved WPF vector, publishes a self-contained .NET bundle with its native runtime, and packages setup plus an optional portable ZIP. WPF is not trimmed. Developer symbols and loose runtime DLLs are excluded from the clean publish output. Packaging never changes or publishes the website.

GitHub Windows CI also checks interactive install, real installed-app launch, upgrade/uninstall/reinstall preservation, startup cleanup, and captures the install cards. The lifecycle script is restricted to disposable CI profiles. Device review on Windows 10/11 and at 100–200% scaling remains necessary before release. This review build is unsigned; Windows publisher reputation/signing is separate work before public launch.
