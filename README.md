# CommonCopy

> Save it once. Paste it forever.

Repository: https://github.com/the-webguy23/CommonCopy.git

CommonCopy is a privacy-friendly utility for saving reusable text and inserting it into the application you are already using. It is designed for email replies, signatures, addresses, code snippets, commands, templates, and any other text you type repeatedly. Windows is currently available; macOS is planned.

## Project status

CommonCopy is an early prototype. The Windows edition includes a functional phrase manager, local JSON persistence, a tray application, a system-wide `Ctrl + Right Click` trigger, highlighted-text capture, a configurable global keyboard shortcut, a popup phrase browser, import/export, backup/restore, Favourites, Commonly Used, and Windows startup registration. Commonly Used ranks saved phrases by use count, then most-recent use. New libraries have Prompts, Code, and Day-to-Day categories; Favourites and Commonly Used are dynamic lists.

The interface offers two appearance options in Settings: Light (Warm Editorial) and Dark (Burnished Copper). The selection is stored with the local phrase library and applies to the manager, popup, and editors. Existing libraries default to Light until the user chooses Dark.

On first launch, CommonCopy copies the existing `%LOCALAPPDATA%\PhraseMenu\phrases.json` and backup to `%LOCALAPPDATA%\CommonCopy` if no CommonCopy library exists. It keeps the old files for rollback and replaces the old Windows startup registration. Existing custom categories, phrases, use counts, and settings stay intact.

The Windows build and installer compiled successfully on September 24, 2026. On a Windows desktop, the upgrade preserved existing phrases, insertion into Notepad and highlighted-text capture worked, Commonly Used appeared, and after a restart CommonCopy started automatically without PhraseMenu. The source archive does not contain built binaries. Broader application compatibility and a separate macOS build remain future work.

## How it works

1. Run CommonCopy; it stays in the Windows notification area.
2. Press `Ctrl + Right Click` or `Ctrl + Shift + Space`.
3. Choose a saved phrase, and CommonCopy restores focus to the previous application and pastes it.

To create a phrase from text that is already on screen:

1. Highlight selectable text in a webpage, document, email, or PDF.
2. Press `Ctrl + Right Click` and choose **Save highlighted text…**.
3. Review the generated title, choose a category, and save.

Normal right-click behavior is not changed unless the configured modifier is held.

## Privacy

- Phrase data is stored locally in `%LOCALAPPDATA%\CommonCopy\phrases.json`.
- CommonCopy does not create an account, upload phrases, transmit clipboard data, or record typed text.
- The global mouse hook checks only for the configured activation gesture. It does not store clicks or keystrokes.
- The application temporarily uses the clipboard to insert phrases and to capture text only when **Save highlighted text…** is explicitly chosen. It can restore the previous text clipboard content afterward.

See [docs/privacy.md](docs/privacy.md) for the detailed privacy model.

## Requirements

- Windows 10 or Windows 11
- .NET 10 SDK for source builds
- Visual Studio with the **.NET desktop development** workload, or the `dotnet` CLI

## Build and run

```powershell
dotnet restore CommonCopy.sln
dotnet build CommonCopy.sln --configuration Debug
dotnet run --project src/CommonCopy.Windows/CommonCopy.Windows.csproj
```

Run tests:

```powershell
dotnet test CommonCopy.sln --configuration Release
```

Create a self-contained Windows x64 build:

```powershell
dotnet publish src/CommonCopy.Windows/CommonCopy.Windows.csproj `
  --configuration Release `
  --runtime win-x64 `
  --self-contained true `
  -p:PublishSingleFile=true `
  --output artifacts/publish/win-x64
```

After installing Inno Setup 6, build and test the app, create both release downloads, generate checksums, and update the local website with one command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-local-release.ps1
```

Exit CommonCopy from its notification-area icon before running the release script.

## Repository layout

| Path | Purpose |
| --- | --- |
| `src/CommonCopy.Core` | Models, catalog operations, validation, and JSON persistence |
| `src/CommonCopy.Windows` | WPF UI, tray icon, input hook, popup, and paste integration |
| `tests/CommonCopy.Core.Tests` | Automated unit tests for storage and catalog behavior |
| `docs` | Architecture, privacy, decisions, and manual compatibility tests |
| `installer` | Inno Setup definition and packaging notes |
| `website` | Static download website |

## Safety note

Do not store passwords, access tokens, private keys, recovery codes, or other secrets in CommonCopy. The initial release stores phrases as readable local JSON.

## Roadmap

- [x] Local phrase library and safe JSON storage
- [x] Phrase manager, categories, Favourites, and Commonly Used
- [x] Tray application and popup browser
- [x] `Ctrl + Right Click` and global hotkey activation
- [x] Save highlighted text from other applications as a new phrase
- [x] Import/export, backup/restore, and startup registration
- [ ] Complete Windows compatibility testing
- [ ] Signed installer and portable release artifacts
- [ ] Accessibility and high-DPI refinement
- [ ] Public download website
- [ ] Optional placeholders such as `{date}` and `{clipboard}`
- [ ] Investigate a separate macOS implementation

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes. Report security issues according to [SECURITY.md](SECURITY.md), not through a public issue.

## License

CommonCopy is licensed under the [MIT License](LICENSE).
