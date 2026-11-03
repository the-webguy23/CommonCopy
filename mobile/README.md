# CommonCopy Mobile — development 0.1

Native iPhone/iPad and Android clients for the same local reusable-text library.
This is development source, not a released App Store or Play Store version.
The desktop apps and published website are unchanged.

## Included

- Local phrase library with add/edit/delete, favourites, category selection, search and nested category creation.
- Desktop schema-1 JSON import/export. Import **replaces** the device library after confirmation; a previous copy is retained locally. Export a portable backup first. No automatic sync.
- A phrase-only keyboard: pick a category and tap a phrase to insert it into the current supported text field. Switch back to your ordinary keyboard to type normally.
- iOS Share extension and Android Share receiver: save text explicitly shared by the user.
- Android selected-text action: save a selection, choose a phrase to replace editable selected text, or copy a phrase when the selection is read-only. The host app controls whether this action is offered.
- No network permission on Android, no network code on either platform, no accounts, analytics, clipboard watching or keystroke logging.
- Existing CommonCopy icon assets, converted deterministically to native icon sizes.

## Supported development targets

- iOS/iPadOS 16+; Xcode with iOS simulator SDK, Swift and XcodeGen.
- Android 11+ (API 30), Java 17, SDK 36, Android Gradle Plugin 8.13.2, Gradle 8.13.

## iPhone / iPad build

On a Mac with Xcode installed:

```sh
brew install xcodegen
cd mobile/ios
swift test
xcodegen generate
open CommonCopyMobile.xcodeproj
```

Select your Apple Developer team for the app and both extensions. The default bundle IDs are `app.commoncopy.mobile`, `.keyboard`, and `.share`. Register/enable `group.app.commoncopy.mobile` for **all three** targets. If those identifiers are unavailable, change the bundle IDs in `project.yml` and `COMMONCOPY_APP_GROUP` consistently, then regenerate. No Apple credentials or signing certificates are included.

Run the CommonCopy scheme on the iPhone. Open the app once, add a phrase, then enable its keyboard under Settings → General → Keyboard → Keyboards → Add New Keyboard. Use the globe key to switch.

**Full Access is not requested.** The keyboard reads the containing app's shared App Group container. It makes no shared-container writes and does not update usage counts. Copying from the main app does update usage counts. Device testing must confirm read-only App Group access on supported iOS versions.

The Share extension appears for text selections passed through the share sheet. Some apps share a page URL rather than selected text; CommonCopy only accepts the text the host actually provides. It cannot add a global item to every iOS Cut/Copy/Paste menu.

For an unsigned simulator compile:

```sh
xcodebuild -project CommonCopyMobile.xcodeproj -scheme CommonCopy -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Simulator output is not an installable iPhone/TestFlight package. Signing and real-device checks are required before distribution.

## Android build

Open `mobile/android` in Android Studio, or use Java 17 and the Android SDK:

```sh
cd mobile/android
./gradlew testDebugUnitTest assembleDebug
```

The debug APK is `app/build/outputs/apk/debug/app-debug.apk`. It is for development testing, not a public release. On the phone, open CommonCopy → Library & keyboard setup → Enable CommonCopy keyboard. Enable it in Android settings, then choose it from the input-method picker. Android shows its standard keyboard-permission notice; the app has no network permission.

Use Share → CommonCopy to save text. Supported selection menus can offer CommonCopy directly, sometimes inside their overflow menu. The action works only where the host supports Android `ACTION_PROCESS_TEXT`; it is not a universal overlay.

## Storage and compatibility

Both clients read and write the desktop `SchemaVersion: 1` object with PascalCase `Categories`, `Phrases` and `Settings` properties. UUIDs, phrase text (including Unicode/newlines), metadata, disabled state and settings survive import/export. Settings belonging to desktop are preserved, not applied on mobile. Favourites and Commonly Used are virtual views rather than stored categories. Category filters select their exact category; nested categories are shown with their full path.

Invalid imports, duplicate IDs, missing parent/category references, category cycles and unsupported schema versions are rejected before replacing data. Android uses AtomicFile plus one process-wide lock. iOS uses NSFileCoordinator around read/modify/write transactions shared by app and Share extension, and atomic file replacement. Existing unreadable data is kept, not silently reset. The previous valid document is stored alongside the current file for recovery; there is no in-app restore UI yet.

The native libraries are readable local text, not encrypted password vaults. Android system backups are disabled. iOS uses the App Group container with file protection until first unlock; operating-system device backups may include app data.

## Validation and release gate

`.github/workflows/mobile.yml` builds the Android debug APK and iOS simulator app, and runs library tests on both platforms. These checks do not prove keyboard or share-sheet behavior on a phone. Follow `DEVICE_TESTS.md` before any signed beta, TestFlight upload or store release. Nothing in this branch publishes a mobile release or changes production download availability.
