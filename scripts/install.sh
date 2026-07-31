#!/usr/bin/env bash
#
# Builds ScreenRead in Release and installs it to /Applications.
#
# Installing to a fixed location matters: macOS ties the Screen Recording
# permission to the app's identity *and* path, so running the binary straight
# out of DerivedData means re-granting permission after every build.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="ScreenRead"
BUILD_DIR=".build"
BUILT_APP="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"

echo "==> Building ${APP_NAME} (Release)"
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    build \
    | grep -E "error:|warning:|BUILD" || true

if [[ ! -d "${BUILT_APP}" ]]; then
    echo "!! Build failed: ${BUILT_APP} not found" >&2
    exit 1
fi

echo "==> Stopping any running instance"
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 1

echo "==> Installing to ${INSTALL_PATH}"
rm -rf "${INSTALL_PATH}"
cp -R "${BUILT_APP}" "${INSTALL_PATH}"
xattr -dr com.apple.quarantine "${INSTALL_PATH}" 2>/dev/null || true

echo "==> Launching"
open "${INSTALL_PATH}"

cat <<'EOF'

Done. Look for the text-viewfinder icon in your menu bar.

If this is the first install, macOS will ask for Screen Recording permission.
Grant it in System Settings > Privacy & Security > Screen Recording, then quit
and relaunch ScreenRead (macOS only applies the new permission on next launch).

Press Cmd+Shift+T to snip.
EOF
