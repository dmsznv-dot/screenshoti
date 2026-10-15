#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP_NAME="Screenshoti"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Sources/Screenshoti/Resources/Info.plist)
STAGING_DIR="build_dmg_staging"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-Installer.dmg"
APP_ONLY=false
if [[ "${1:-}" == "--app-only" ]]; then APP_ONLY=true; shift; fi
swift build -c release "$@"
BUILD_DIR=$(swift build -c release --show-bin-path "$@")
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Sources/Screenshoti/Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set CFBundleExecutable ${APP_NAME}" "${APP_BUNDLE}/Contents/Info.plist"
plutil -lint "${APP_BUNDLE}/Contents/Info.plist"
codesign --force --sign - --entitlements Sources/Screenshoti/Resources/Screenshoti.entitlements "${APP_BUNDLE}"
codesign --verify --strict "${APP_BUNDLE}"
if [[ "$APP_ONLY" == true ]]; then echo "App ready: ${APP_BUNDLE}"; exit 0; fi
if [[ ! -L "${STAGING_DIR}/Applications" ]]; then ln -s /Applications "${STAGING_DIR}/Applications"; fi
hdiutil create -volname "${APP_NAME} Installer" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
echo "Installer ready: ${DMG_NAME}"
