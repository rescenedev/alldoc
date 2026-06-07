#!/bin/bash
# AllDoc 를 빌드해 .app 번들을 만든다. (Xcode 없이 SwiftPM + 수동 번들링)
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"
APP_NAME="AllDoc"
BUNDLE_ID="com.alldoc.app"
CONFIG="${1:-release}"

echo "▶ SwiftPM 빌드 ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "✗ 실행 파일을 찾을 수 없음: $BIN_PATH"; exit 1
fi

APP_DIR="$ROOT/build/$APP_NAME.app"
echo "▶ 번들 생성: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# ----- 아이콘 생성 -----
echo "▶ 아이콘 생성…"
ICON_PNG="$ROOT/build/icon_1024.png"
mkdir -p "$ROOT/build"
if swift "$ROOT/Tools/make_icon.swift" "$ICON_PNG" >/dev/null 2>&1; then
  ICONSET="$ROOT/build/AllDoc.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  for s in 16 32 64 128 256 512; do
    sips -z $s $s "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s*2))
    sips -z $d $d "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  if iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    HAS_ICON=1
  else
    HAS_ICON=0
  fi
else
  echo "  (아이콘 생성 건너뜀)"
  HAS_ICON=0
fi

# ----- Info.plist -----
echo "▶ Info.plist 작성…"
ICON_KEY=""
if [[ "${HAS_ICON:-0}" == "1" ]]; then
  ICON_KEY="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>AllDoc 문서관리</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
$ICON_KEY
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>AllDoc</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>데스크탑의 문서를 탐색하고 검색합니다.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>문서 폴더의 문서를 탐색하고 검색합니다.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>다운로드 폴더의 문서를 탐색하고 검색합니다.</string>
</dict>
</plist>
PLIST

# ----- 코드사인 (ad-hoc) -----
echo "▶ ad-hoc 코드사인…"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "  (코드사인 건너뜀)"

echo ""
echo "✅ 완료: $APP_DIR"
echo "   실행: open \"$APP_DIR\""
