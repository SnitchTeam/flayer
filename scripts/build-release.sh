#!/usr/bin/env bash
# Build, ad-hoc sign, and package a FlaYer release DMG — no Apple Developer
# account required. The resulting DMG trips Gatekeeper on first open; the
# README documents the one-time right-click → Open workaround for users.
#
# Usage: ./scripts/build-release.sh [VERSION]
# Example: ./scripts/build-release.sh 1.2
#
# Environment overrides:
#   SCHEME         Xcode scheme to archive    (default: FlaYer)
#   CONFIGURATION  Build configuration        (default: Release)
#   OUTPUT_DIR     Where artefacts land       (default: ./build/release)
#   DEV_ID         Codesign identity          (default: "-" for ad-hoc)
#                  Set to your Developer ID if you ever get an Apple account.
#
# Requires: Xcode command-line tools, xcodegen, create-dmg.
#   brew install xcodegen create-dmg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/macos/MusicApp"

SCHEME="${SCHEME:-FlaYer}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build/release}"
DEV_ID="${DEV_ID:--}"
VERSION="${1:-$(date +%Y%m%d)}"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v xcodebuild >/dev/null || die "xcodebuild not found — install Xcode command-line tools."
command -v xcodegen   >/dev/null || die "xcodegen not found — brew install xcodegen"
command -v create-dmg >/dev/null || die "create-dmg not found — brew install create-dmg"

[[ -f "$PROJECT_DIR/project.yml" ]] || die "expected $PROJECT_DIR/project.yml"

log "Regenerating Xcode project from project.yml"
(cd "$PROJECT_DIR" && xcodegen generate)

ARCHIVE_PATH="$OUTPUT_DIR/FlaYer.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
DMG_PATH="$OUTPUT_DIR/FlaYer-$VERSION.dmg"

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$OUTPUT_DIR"

log "Archiving $SCHEME ($CONFIGURATION)"
xcodebuild \
  -project "$PROJECT_DIR/FlaYer.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_IDENTITY="$DEV_ID" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES | xcpretty 2>/dev/null || {
    # xcpretty is optional; re-run unfiltered if it is missing.
    xcodebuild \
      -project "$PROJECT_DIR/FlaYer.xcodeproj" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -destination 'generic/platform=macOS' \
      -archivePath "$ARCHIVE_PATH" \
      archive \
      CODE_SIGN_IDENTITY="$DEV_ID" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=YES
}

APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/FlaYer.app"
[[ -d "$APP_IN_ARCHIVE" ]] || die "archive did not produce $APP_IN_ARCHIVE"

log "Exporting .app"
mkdir -p "$EXPORT_PATH"
cp -R "$APP_IN_ARCHIVE" "$EXPORT_PATH/FlaYer.app"

log "Ad-hoc signing (identity: $DEV_ID)"
# --force overrides any prior signature; --deep is required for embedded
# frameworks; --options runtime keeps the hardened-runtime flag so future
# notarisation is straightforward if you ever get a Developer ID cert.
codesign --force --deep --options runtime --sign "$DEV_ID" "$EXPORT_PATH/FlaYer.app"

log "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$EXPORT_PATH/FlaYer.app" || true
spctl --assess --type execute --verbose "$EXPORT_PATH/FlaYer.app" || \
  printf '\033[1;33mnote:\033[0m spctl rejected the app — expected without a Developer ID. First-run users must right-click → Open.\n'

log "Packaging DMG → $DMG_PATH"
rm -f "$DMG_PATH"
create-dmg \
  --volname "FlaYer $VERSION" \
  --window-pos 200 120 \
  --window-size 540 360 \
  --icon-size 96 \
  --icon "FlaYer.app" 140 180 \
  --hide-extension "FlaYer.app" \
  --app-drop-link 400 180 \
  "$DMG_PATH" \
  "$EXPORT_PATH"

log "Done"
printf '\n  DMG: %s\n  Size: %s\n  SHA-256: %s\n\n' \
  "$DMG_PATH" \
  "$(du -h "$DMG_PATH" | awk '{print $1}')" \
  "$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
