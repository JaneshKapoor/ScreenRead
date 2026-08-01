#!/usr/bin/env bash
#
# Builds ScreenRead in Release and installs it to /Applications.
#
# Installing to a fixed location matters: macOS ties the Screen Recording
# permission to the app's code signature, so running the binary straight out of
# a build folder means re-granting permission after every build.

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="ScreenRead"
INSTALL_PATH="/Applications/${APP_NAME}.app"

# Build outside the repo. If the project lives in an iCloud-synced folder
# (Desktop/Documents), the sync daemon stamps com.apple.FinderInfo onto the
# build output and codesign refuses to sign it: "resource fork, Finder
# information, or similar detritus not allowed".
BUILD_DIR="${HOME}/Library/Caches/${APP_NAME}-build"
BUILT_APP="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
LOG_FILE="${BUILD_DIR}/xcodebuild.log"

mkdir -p "${BUILD_DIR}"

echo "==> Building ${APP_NAME} (Release)"
if ! xcodebuild \
        -project "${APP_NAME}.xcodeproj" \
        -scheme "${APP_NAME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}" \
        -allowProvisioningUpdates \
        build > "${LOG_FILE}" 2>&1; then
    echo "!! Build failed. Last 30 lines:" >&2
    tail -30 "${LOG_FILE}" >&2
    echo "!! Full log: ${LOG_FILE}" >&2
    exit 1
fi

if [[ ! -d "${BUILT_APP}" ]]; then
    echo "!! Build reported success but ${BUILT_APP} is missing" >&2
    exit 1
fi

echo "==> Stopping any running instance"
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 1

echo "==> Installing to ${INSTALL_PATH}"
rm -rf "${INSTALL_PATH}"
cp -R "${BUILT_APP}" "${INSTALL_PATH}"
xattr -cr "${INSTALL_PATH}" 2>/dev/null || true

echo "==> Launching"
open "${INSTALL_PATH}"

cat <<'EOF'

Done. Look for the text-viewfinder icon in your menu bar.

If this is the first install, macOS will ask for Screen Recording permission.
Grant it in System Settings > Privacy & Security > Screen Recording, then quit
and relaunch ScreenRead (macOS only applies the new permission on next launch).

Press Cmd+Shift+T to snip.
EOF
