#!/bin/bash
set -euo pipefail

# Run on a Mac with .NET 10 and Xcode Command Line Tools installed.
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "This build requires macOS and Apple's Swift SDK." >&2
  exit 1
fi
architecture="${1:-arm64}"
case "$architecture" in
  arm64) runtime=osx-arm64 ;;
  x86_64) runtime=osx-x64 ;;
  *) echo "Use arm64 or x86_64." >&2; exit 1 ;;
esac

dotnet test tests/CommonCopy.Core.Tests/CommonCopy.Core.Tests.csproj --configuration Release
swift build --package-path src/CommonCopy.Mac --configuration release --arch "$architecture"
binary_dir="$(swift build --package-path src/CommonCopy.Mac --configuration release --arch "$architecture" --show-bin-path)"
app="$root/artifacts/macos-$architecture/CommonCopy.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers/Core"
cp "$binary_dir/CommonCopyMac" "$app/Contents/MacOS/"
cp src/CommonCopy.Mac/Info.plist "$app/Contents/Info.plist"
dotnet publish src/CommonCopy.DesktopBridge/CommonCopy.DesktopBridge.csproj \
  --configuration Release --runtime "$runtime" --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=false \
  --output "$app/Contents/Helpers/Core"

# Ad-hoc signatures are for private testing only, not Developer ID notarization.
# .NET requires JIT permission; the Swift shell itself does not.
cat > "$root/artifacts/macos-$architecture/core-entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.cs.allow-jit</key><true/>
</dict></plist>
PLIST
while IFS= read -r -d '' library; do
  codesign --force --sign - "$library"
done < <(find "$app/Contents/Helpers/Core" -name '*.dylib' -print0)
codesign --force --sign - --entitlements "$root/artifacts/macos-$architecture/core-entitlements.plist" \
  "$app/Contents/Helpers/Core/CommonCopy.DesktopBridge"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"

# Smoke-test the actual packaged helper, using disposable data rather than a real library.
test_data="$(mktemp -d)"
trap 'rm -rf "$test_data"' EXIT
printf '%s' '{"operation":"snapshot"}' | "$app/Contents/Helpers/Core/CommonCopy.DesktopBridge" "$test_data" \
  > "$test_data/response.json"
python3 - "$test_data/response.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    response = json.load(stream)
assert response['ok']
assert any(c['name'] == 'Prompts' for c in response['state']['document']['categories'])
PY
cp docs/macos-testing.md "$root/artifacts/macos-$architecture/READ-ME-FIRST.md"
ditto -c -k --sequesterRsrc --keepParent "$app" "$root/artifacts/CommonCopy-macos-$architecture.zip"
echo "Built $app"
