#!/usr/bin/env bash
# Builds "dist/Where's My Mouse.app" with the Command Line Tools (no Xcode needed).
#
#   ./build.sh             build "dist/Where's My Mouse.app"
#   ./build.sh --install   build, copy to /Applications, and launch
#   ./build.sh --dmg       build, then make dist/WheresMyMouse.dmg (drag-to-Applications)
#
# Env:
#   ARCH=universal         build arm64 + x86_64 (default: this Mac's arch)
#   SIGN_IDENTITY="Name"   codesign identity. Defaults to "WheresMyMouse Self-Signed"
#                          if scripts/setup-signing.sh has been run, else ad-hoc "-".
#                          A stable identity keeps Full Disk Access across rebuilds.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Where's My Mouse"   # the .app shown in Finder
EXECUTABLE=WheresMyMouse
BUNDLE_ID=com.wheresmymouse.WheresMyMouse
APP="dist/$APP_NAME.app"
ARCH="${ARCH:-$(uname -m)}"
SELF_SIGNED="WheresMyMouse Self-Signed"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    if security find-certificate -c "$SELF_SIGNED" >/dev/null 2>&1; then
        SIGN_IDENTITY="$SELF_SIGNED"
    else
        SIGN_IDENTITY="-"
        echo "Note: ad-hoc signing. Run scripts/setup-signing.sh once so Full Disk Access survives rebuilds."
    fi
fi
SDK="$(xcrun --show-sdk-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build

compile() {
    swiftc -O -parse-as-library -sdk "$SDK" -target "$1-apple-macos13.0" Sources/*.swift -o "$2"
}

echo "Compiling ($ARCH)…"
if [[ "$ARCH" == universal ]]; then
    compile arm64 build/$EXECUTABLE-arm64
    compile x86_64 build/$EXECUTABLE-x86_64
    lipo -create build/$EXECUTABLE-arm64 build/$EXECUTABLE-x86_64 -output "$APP/Contents/MacOS/$EXECUTABLE"
else
    compile "$ARCH" "$APP/Contents/MacOS/$EXECUTABLE"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP (signed: $SIGN_IDENTITY)"

if [[ "${1:-}" == "--dmg" ]]; then
    STAGING="build/dmg"
    rm -rf "$STAGING" "dist/$EXECUTABLE.dmg"
    mkdir -p "$STAGING"
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "dist/$EXECUTABLE.dmg" >/dev/null
    rm -rf "$STAGING"
    echo "Built dist/$EXECUTABLE.dmg"
fi

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$EXECUTABLE" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    open "/Applications/$APP_NAME.app"
    echo "Installed to /Applications/$APP_NAME.app"
fi
