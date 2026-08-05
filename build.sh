#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PayTick"
APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 清理旧产物
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "[1/3] Compiling Swift sources..."

SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)"

# 拉取所有源文件
SOURCES=$(find "$PROJECT_ROOT/Sources" -name "*.swift" | sort)

swiftc \
    -O \
    -parse-as-library \
    -target arm64-apple-macosx13.0 \
    -sdk "$SDK_PATH" \
    -framework AppKit \
    -framework SwiftUI \
    -framework UserNotifications \
    $SOURCES \
    -o "$MACOS_DIR/$APP_NAME"

echo "[2/3] Assembling bundle..."

cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_ROOT/Resources/notif.mp3" "$RESOURCES_DIR/notif.mp3"
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 给可执行文件权限
chmod +x "$MACOS_DIR/$APP_NAME"

echo "[3/3] Build complete."
echo ""
echo "  Bundle:  $APP_BUNDLE"
echo "  Binary:  $MACOS_DIR/$APP_NAME"
echo ""
echo "Run with: open '$APP_BUNDLE'"
