#!/bin/bash
set -e

APP_NAME="Screenshoti"
BUNDLE_ID="com.dmsznv.screenshoti"
VERSION="1.0.0"
BUILD_DIR=".build/release"
STAGING_DIR="build_dmg_staging"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-Installer.dmg"

echo "🔨 1/5: Сборка релизной версии ${APP_NAME} (Universal / Native)..."
swift build -c release

echo "📦 2/5: Формирование структуры macOS приложения (${APP_NAME}.app)..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Копирование бинарного файла
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Копирование Info.plist с подстановкой переменных
sed "s/\$(EXECUTABLE_NAME)/${APP_NAME}/g" "Sources/Screenshoti/Resources/Info.plist" > "${APP_BUNDLE}/Contents/Info.plist"

# Копирование ресурсов (если есть бандл SwiftPM)
if [ -d "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${APP_BUNDLE}/Contents/Resources/"
fi

echo "🔏 3/5: Локальная подпись приложения (Ad-Hoc Code Signing) и применение Entitlements..."
codesign --force --deep --sign - --entitlements "Sources/Screenshoti/Resources/Screenshoti.entitlements" "${APP_BUNDLE}"

echo "🔗 4/5: Добавление ярлыка папки Applications для удобного перетаскивания (Drag & Drop)..."
ln -s /Applications "${STAGING_DIR}/Applications"

echo "💿 5/5: Упаковка в установочный образ ${DMG_NAME}..."
if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
      --volname "${APP_NAME} Installer" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "${APP_NAME}.app" 160 185 \
      --hide-extension "${APP_NAME}.app" \
      --app-drop-link 440 185 \
      "${DMG_NAME}" \
      "${STAGING_DIR}/"
else
    hdiutil create -volname "${APP_NAME} Installer" \
      -srcfolder "${STAGING_DIR}" \
      -ov -format UDZO \
      "${DMG_NAME}"
fi

rm -rf "$STAGING_DIR"
echo "✅ Готово! Установочный файл создан: $(pwd)/${DMG_NAME}"
open -R "${DMG_NAME}" || true
