#!/bin/bash

# Builds MarkdownViewCatalog, wraps it in an app bundle and opens it.
#
#   Script/catalog.sh            debug build
#   Script/catalog.sh release    release build

set -e

cd "$(dirname "$0")"
cd ..

CONFIGURATION=${1:-debug}
PRODUCT="MarkdownViewCatalog"

swift build -c "$CONFIGURATION" --product "$PRODUCT"
BIN_DIR=$(swift build -c "$CONFIGURATION" --show-bin-path)

APP="$BIN_DIR/$PRODUCT.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
# SwiftPM stamps the deployment target as the SDK version, so AppKit would run
# the app in its macOS 13 compatibility look. Record the SDK it was built with.
vtool -set-build-version macos 13.0 "$(xcrun --sdk macosx --show-sdk-version)" -replace \
    -output "$APP/Contents/MacOS/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
# Inside an app, SwiftPM's Bundle.module looks in the main bundle's resources.
find "$BIN_DIR" -maxdepth 1 -name "*.bundle" ! -name "*Tests.bundle" \
    -exec cp -R {} "$APP/Contents/Resources/" \;

# actool writes CatalogIcon.icns and Assets.car; it needs an absolute path, or it
# exits cleanly without writing either.
xcrun actool "$PWD/Artworks/CatalogIcon.icon" \
    --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 13.0 \
    --app-icon CatalogIcon \
    --output-partial-info-plist "$BIN_DIR/$PRODUCT-icon.plist" >/dev/null

cat >"$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT</string>
    <key>CFBundleIdentifier</key>
    <string>wiki.qaq.MarkdownViewCatalog</string>
    <key>CFBundleIconFile</key>
    <string>CatalogIcon</string>
    <key>CFBundleIconName</key>
    <string>CatalogIcon</string>
    <key>CFBundleName</key>
    <string>MarkdownView Catalog</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "[*] $APP"
open "$APP"
