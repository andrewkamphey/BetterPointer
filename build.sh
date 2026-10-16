#!/usr/bin/env bash
# Builds "dist/Where's My Mouse.app" with the Command Line Tools (no Xcode needed).
#
#   ./build.sh             build "dist/Where's My Mouse.app"
#   ./build.sh --install   build, copy to /Applications, and launch
#   ./build.sh --dmg       build, then make dist/WheresMyMouse.dmg (drag-to-Applications)
#   ./build.sh --notarize  --dmg, then notarize and staple it (needs a Developer ID identity
#                          and APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD)
#
# Env:
#   ARCH=universal         build arm64 + x86_64 (default: this Mac's arch)
#   SIGN_IDENTITY="Name"   codesign identity. Defaults to a "Developer ID Application" identity
#                          if one is in the keychain, else "WheresMyMouse Self-Signed"
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
    DEVELOPER_ID="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
    if [[ -n "$DEVELOPER_ID" ]]; then
        SIGN_IDENTITY="$DEVELOPER_ID"
    elif security find-certificate -c "$SELF_SIGNED" >/dev/null 2>&1; then
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
    swiftc -O -parse-as-library -sdk "$SDK" -target "$1-apple-macos11.0" Sources/*.swift -o "$2"
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

if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]]; then
    # Notarization requires the hardened runtime and a secure timestamp.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
else
    codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
fi
echo "Built $APP (signed: $SIGN_IDENTITY)"

if [[ "${1:-}" == "--dmg" || "${1:-}" == "--notarize" ]]; then
    STAGING="build/dmg"
    rm -rf "$STAGING" "dist/$EXECUTABLE.dmg"
    mkdir -p "$STAGING"
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "dist/$EXECUTABLE.dmg" >/dev/null
    rm -rf "$STAGING"
    [[ "$SIGN_IDENTITY" != "-" ]] && codesign --force --timestamp --sign "$SIGN_IDENTITY" "dist/$EXECUTABLE.dmg"
    echo "Built dist/$EXECUTABLE.dmg"
fi

if [[ "${1:-}" == "--notarize" ]]; then
    : "${APPLE_ID:?}" "${APPLE_TEAM_ID:?}" "${APPLE_APP_PASSWORD:?}"
    echo "Notarizing (usually a few minutes)…"
    xcrun notarytool submit "dist/$EXECUTABLE.dmg" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" --wait --timeout 30m
    xcrun stapler staple "dist/$EXECUTABLE.dmg"
    xcrun stapler staple "$APP"   # the DMG's ticket covers the app too, for the zip
    spctl --assess --type open --context context:primary-signature -v "dist/$EXECUTABLE.dmg"
    echo "Notarized dist/$EXECUTABLE.dmg"
fi

if [[ "${1:-}" == "--install" ]]; then
    pkill -x "$EXECUTABLE" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    open "/Applications/$APP_NAME.app"
    echo "Installed to /Applications/$APP_NAME.app"
fi
