#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Valen"
EXECUTABLE_NAME="valen"
BUNDLE_ID="${BUNDLE_ID:-dev.valen.player}"
VERSION="${VERSION:-0.2.1}"
BUILD_NUMBER="${BUILD_NUMBER:-4}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macos-arm64.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS_FILE="$ROOT_DIR/Packaging/Valen.entitlements"
ICON_SOURCE="$ROOT_DIR/Icons/Valen-iOS-Default-1024x1024@1x.png"
ICONSET_DIR="$DIST_DIR/Valen.iconset"
ICON_FILE="$RESOURCES_DIR/Valen.icns"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$BUILD_DIR/valen-mcp" "$MACOS_DIR/valen-mcp"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>Valen</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Media File</string>
      <key>CFBundleTypeIconFile</key>
      <string>Valen</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>mkv</string>
        <string>mka</string>
        <string>webm</string>
        <string>mp4</string>
        <string>mov</string>
        <string>m4v</string>
        <string>avi</string>
        <string>flv</string>
        <string>wmv</string>
        <string>mp3</string>
        <string>flac</string>
        <string>ogg</string>
        <string>wav</string>
      </array>
      <key>LSItemContentTypes</key>
      <array>
        <string>org.matroska.mkv</string>
        <string>org.matroska.mka</string>
        <string>org.webmproject.webm</string>
        <string>public.mpeg-4</string>
        <string>com.apple.quicktime-movie</string>
        <string>public.avi</string>
        <string>com.microsoft.windows-media-wmv</string>
        <string>public.mp3</string>
        <string>org.xiph.flac</string>
        <string>org.xiph.ogg</string>
        <string>com.microsoft.waveform-audio</string>
      </array>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
    </dict>
  </array>
  <key>UTImportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.matroska.mkv</string>
      <key>UTTypeDescription</key>
      <string>Matroska Video</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.movie</string>
        <string>public.audiovisual-content</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>mkv</string>
        </array>
        <key>public.mime-type</key>
        <array>
          <string>video/x-matroska</string>
        </array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.matroska.mka</string>
      <key>UTTypeDescription</key>
      <string>Matroska Audio</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.audio</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>mka</string>
        </array>
        <key>public.mime-type</key>
        <array>
          <string>audio/x-matroska</string>
        </array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.webmproject.webm</string>
      <key>UTTypeDescription</key>
      <string>WebM Video</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.movie</string>
        <string>public.audiovisual-content</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>webm</string>
        </array>
        <key>public.mime-type</key>
        <array>
          <string>video/webm</string>
        </array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.xiph.flac</string>
      <key>UTTypeDescription</key>
      <string>FLAC Audio</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.audio</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>flac</string>
        </array>
        <key>public.mime-type</key>
        <array>
          <string>audio/flac</string>
        </array>
      </dict>
    </dict>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.xiph.ogg</string>
      <key>UTTypeDescription</key>
      <string>Ogg Media</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.audiovisual-content</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>ogg</string>
        </array>
        <key>public.mime-type</key>
        <array>
          <string>audio/ogg</string>
          <string>video/ogg</string>
        </array>
      </dict>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
$(if [[ -n "$SPARKLE_FEED_URL" ]]; then cat <<SPARKLE_PLIST
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
SPARKLE_PLIST
fi)
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if [[ -f "$ICON_SOURCE" ]]; then
  sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  cp "$ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
  rm -rf "$ICONSET_DIR"
else
  echo "warning: icon source not found: $ICON_SOURCE" >&2
fi

copy_dependency() {
  local dylib="$1"
  local dest="$FRAMEWORKS_DIR/$(basename "$dylib")"

  if [[ "$dylib" != /opt/homebrew/* && "$dylib" != /usr/local/* ]]; then
    return
  fi

  if [[ ! -f "$dest" ]]; then
    cp "$dylib" "$dest"
    chmod u+w "$dest"

    local dep
    while IFS= read -r dep; do
      copy_dependency "$dep"
    done < <(otool -L "$dest" | awk 'NR > 1 {print $1}' | grep -E '^(/opt/homebrew|/usr/local)/' || true)
  fi
}

while IFS= read -r dep; do
  copy_dependency "$dep"
done < <(otool -L "$MACOS_DIR/$EXECUTABLE_NAME" | awk 'NR > 1 {print $1}' | grep -E '^(/opt/homebrew|/usr/local)/' || true)

rewrite_load_paths() {
  local binary="$1"
  local id_name="${2:-}"

  chmod u+w "$binary"

  if [[ -n "$id_name" ]]; then
    install_name_tool -id "@executable_path/../Frameworks/$id_name" "$binary" || true
  fi

  local dep
  while IFS= read -r dep; do
    install_name_tool -change "$dep" "@executable_path/../Frameworks/$(basename "$dep")" "$binary"
  done < <(otool -L "$binary" | awk 'NR > 1 {print $1}' | grep -E '^(/opt/homebrew|/usr/local)/' || true)
}

rewrite_load_paths "$MACOS_DIR/$EXECUTABLE_NAME"

for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
  [[ -e "$dylib" ]] || continue
  rewrite_load_paths "$dylib" "$(basename "$dylib")"
done

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --entitlements "$ENTITLEMENTS_FILE" --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Built $APP_DIR"
echo "Created $ZIP_PATH"
