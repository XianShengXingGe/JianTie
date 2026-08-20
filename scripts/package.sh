#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.1.0}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/dist"
STAGE_DIR="/tmp/jiantie_package_${VERSION}_$$"
APP_NAME="简贴"
APP_BUNDLE="${STAGE_DIR}/${APP_NAME}.app"
DMG_STAGE="${STAGE_DIR}/dmg_root"

echo "=== 1. Starting formal release build for ${APP_NAME} v${VERSION} ==="
echo "Project root: ${PROJECT_ROOT}"
echo "Staging dir:  ${STAGE_DIR}"

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}" "${BUILD_DIR}"

echo "=== 2. Compiling Universal Binary (arm64 + x86_64) ==="
cd "${PROJECT_ROOT}"

echo "-> Building arm64 release binary..."
swift build -c release --triple arm64-apple-macosx13.0

echo "-> Building x86_64 release binary..."
swift build -c release --triple x86_64-apple-macosx13.0

echo "=== 3. Creating App Bundle Structure ==="
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "-> Merging Universal Mach-O with lipo..."
lipo -create \
  "${PROJECT_ROOT}/.build/arm64-apple-macosx/release/JianTie" \
  "${PROJECT_ROOT}/.build/x86_64-apple-macosx/release/JianTie" \
  -output "${APP_BUNDLE}/Contents/MacOS/JianTie"

chmod +x "${APP_BUNDLE}/Contents/MacOS/JianTie"
lipo -info "${APP_BUNDLE}/Contents/MacOS/JianTie"

echo "-> Copying Info.plist and PkgInfo..."
cp "${PROJECT_ROOT}/Sources/JianTieApp/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "-> Copying Resource Bundles and Assets..."
# Copy SPM Resource Bundles
if [ -d "${PROJECT_ROOT}/.build/arm64-apple-macosx/release/JianTie_JianTieApp.bundle" ]; then
    cp -R "${PROJECT_ROOT}/.build/arm64-apple-macosx/release/JianTie_JianTieApp.bundle" "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -d "${PROJECT_ROOT}/.build/arm64-apple-macosx/release/JianTie_JianTieCore.bundle" ]; then
    cp -R "${PROJECT_ROOT}/.build/arm64-apple-macosx/release/JianTie_JianTieCore.bundle" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy App Icons, QRCodes and Localization resources directly into Resources
for item in "${PROJECT_ROOT}/Sources/JianTieApp/Resources"/*; do
    if [ -e "${item}" ]; then
        cp -R "${item}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done

echo "=== 4. Sanitizing and Code Signing ==="
# Strip any quarantine / extended attributes / iCloud metadata
xattr -cr "${APP_BUNDLE}"
find "${APP_BUNDLE}" -name ".DS_Store" -delete

# Sign internal bundles first if present
find "${APP_BUNDLE}/Contents/Resources" -maxdepth 1 -name "*.bundle" | while read -r bundle; do
    if [ -d "${bundle}" ]; then
        codesign --force --sign - --timestamp=none "${bundle}"
    fi
done

# Sign the main application bundle
codesign --force --deep --sign - --options runtime --timestamp=none "${APP_BUNDLE}"

echo "-> Verifying code signature..."
codesign --verify --deep --strict --verbose=4 "${APP_BUNDLE}"

echo "=== 5. Packaging DMG and ZIP ==="
mkdir -p "${DMG_STAGE}"
cp -R "${APP_BUNDLE}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

DMG_OUT="${BUILD_DIR}/JianTie-v${VERSION}.dmg"
ZIP_OUT="${BUILD_DIR}/JianTie-v${VERSION}.zip"

rm -f "${DMG_OUT}" "${ZIP_OUT}"

echo "-> Creating DMG: ${DMG_OUT}..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGE}" \
  -ov \
  -format UDZO \
  "${DMG_OUT}"

echo "-> Verifying DMG..."
hdiutil verify "${DMG_OUT}"

echo "-> Creating ZIP: ${ZIP_OUT}..."
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_OUT}"

# Also sync the clean .app back to project root
rm -rf "${PROJECT_ROOT}/${APP_NAME}.app"
cp -R "${APP_BUNDLE}" "${PROJECT_ROOT}/${APP_NAME}.app"

# Clean up staging
rm -rf "${STAGE_DIR}"

echo "=== Packaging Complete! ==="
ls -lh "${BUILD_DIR}/JianTie-v${VERSION}.dmg" "${BUILD_DIR}/JianTie-v${VERSION}.zip" "${PROJECT_ROOT}/${APP_NAME}.app"
