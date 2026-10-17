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
swift test --package-path src/CommonCopy.Mac --configuration release --arch "$architecture"
binary_dir="$(swift build --package-path src/CommonCopy.Mac --configuration release --arch "$architecture" --show-bin-path)"
app="$root/artifacts/macos-$architecture/CommonCopy.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers/Core" "$app/Contents/Resources"
cp "$binary_dir/CommonCopyMac" "$app/Contents/MacOS/"
cp docs/help/help.html "$app/Contents/Resources/help.html"
cp src/CommonCopy.Mac/Info.plist "$app/Contents/Info.plist"
cp src/CommonCopy.Mac/Assets/CommonCopyLogo.svg "$app/Contents/Resources/CommonCopyLogo.svg"
# Preserve all vector geometry; use the brand reverse colors on dark surfaces.
python3 - "$app/Contents/Resources" <<'PYLOGO'
from pathlib import Path
import sys
resources = Path(sys.argv[1])
source = (resources / 'CommonCopyLogo.svg').read_text()
(resources / 'CommonCopyLogoReverse.svg').write_text(source.replace('fill="#000000"', 'fill="#FFFFFF"').replace('fill="#585858"', 'fill="#AAAAAA"'))
PYLOGO
# Render platform icon sizes directly from the approved vector master.
swift scripts/render-macos-icon.swift src/CommonCopy.Mac/Assets/CommonCopyLogo.svg "$app/Contents/Resources/CommonCopyLogo.png"
# Derive standard macOS icon sizes from the approved artwork, without redrawing it.
iconset="$root/artifacts/CommonCopy.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$app/Contents/Resources/CommonCopyLogo.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$app/Contents/Resources/CommonCopyLogo.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/CommonCopy.icns"
dotnet publish src/CommonCopy.DesktopBridge/CommonCopy.DesktopBridge.csproj \
  --configuration Release --runtime "$runtime" --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=false \
  -p:DebugType=None -p:DebugSymbols=false \
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
cmp docs/help/help.html "$app/Contents/Resources/help.html"

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
