#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

release_identity=${RELEASE_SIGNING_IDENTITY:--}
notary_profile=${NOTARYTOOL_PROFILE:-}
if [ -n "$notary_profile" ] && [ "$release_identity" = "-" ]; then
    echo "Notarization requires RELEASE_SIGNING_IDENTITY to be a Developer ID Application certificate." >&2
    exit 1
fi

mkdir -p build dist
echo "Building Aero for Apple silicon and Intel Macs…"
if [ "$release_identity" = "-" ]; then
    xcodebuild -project Aero.xcodeproj -scheme Aero -configuration Release \
        -derivedDataPath build/release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="$release_identity" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
        build > build/release-build.log 2>&1 || { tail -n 80 build/release-build.log; exit 1; }
else
    xcodebuild -project Aero.xcodeproj -scheme Aero -configuration Release \
        -derivedDataPath build/release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="$release_identity" CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
        OTHER_CODE_SIGN_FLAGS="--timestamp" \
        build > build/release-build.log 2>&1 || { tail -n 80 build/release-build.log; exit 1; }
fi

release_app=build/release/Build/Products/Release/Aero.app
codesign --verify --deep --strict "$release_app"
lipo "$release_app/Contents/MacOS/Aero" -verify_arch arm64
lipo "$release_app/Contents/MacOS/Aero" -verify_arch x86_64
release_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$release_app/Contents/Info.plist")
release_name="Aero-$release_version-universal.dmg"

release_stage=$(mktemp -d /tmp/aero-dmg.XXXXXX)
trap 'rm -rf "$release_stage"' EXIT
ditto "$release_app" "$release_stage/Aero.app"
ln -s /Applications "$release_stage/Applications"
cp LICENSE ATTRIBUTION.md docs/INSTALL.txt "$release_stage/"
hdiutil create -volname Aero -srcfolder "$release_stage" -format UDZO -ov "dist/$release_name"

if [ "$release_identity" != "-" ]; then
    codesign --force --sign "$release_identity" --timestamp "dist/$release_name"
fi
if [ -n "$notary_profile" ]; then
    xcrun notarytool submit "dist/$release_name" --keychain-profile "$notary_profile" --wait
    xcrun stapler staple "dist/$release_name"
    xcrun stapler validate "dist/$release_name"
fi
hdiutil verify "dist/$release_name"
(cd dist && shasum -a 256 "$release_name" > SHA256SUMS.txt)
echo "Created dist/$release_name and dist/SHA256SUMS.txt"
if [ -z "$notary_profile" ]; then
    echo "This build is not notarized. Label it accordingly when distributing it."
fi
