# Contributing to CommonCopy

Thank you for helping improve CommonCopy.

## Before opening a change

1. Search existing issues and pull requests.
2. Open an issue for substantial behavior or architecture changes.
3. Keep the application local-first and dependency-light.
4. Never add telemetry, network transmission, credential storage, or advertising to the desktop application without an explicit project decision.

## Development workflow

1. Create a focused branch.
2. Build with `dotnet build CommonCopy.sln`.
3. Run `dotnet test CommonCopy.sln`.
4. Manually test any Windows integration you changed.
5. Update documentation and `CHANGELOG.md` when behavior changes.
6. Submit a pull request describing the problem, solution, tests, and remaining limitations.

## Code guidelines

- Prefer clear platform APIs over large frameworks.
- Keep operating-system integration in `CommonCopy.Windows`.
- Keep reusable business logic and storage in `CommonCopy.Core`.
- Make data migrations explicit and backward compatible.
- Treat clipboard contents and saved phrases as sensitive user data.

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
