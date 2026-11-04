#!/bin/bash
# Source this file; successful checks print only the bundle's architecture.
commoncopy_macos_architecture() {
  local app="$1" architecture
  architecture="$(lipo -archs "$app/Contents/MacOS/CommonCopyMac")" || return 1
  case "$architecture" in
    arm64|x86_64) ;;
    *) echo "Expected one supported Mac architecture, got: $architecture" >&2; return 1 ;;
  esac
  lipo "$app/Contents/Helpers/Core/CommonCopy.DesktopBridge" -verify_arch "$architecture" || return 1
  printf '%s\n' "$architecture"
}
