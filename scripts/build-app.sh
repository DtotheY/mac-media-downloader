#!/bin/zsh

set -e

PROJECT_ROOT="${0:A:h:h}"
DIST_DIR="$PROJECT_ROOT/dist"
APP_PATH="$DIST_DIR/多平台媒体下载器.app"
CONTENTS="$APP_PATH/Contents"

mkdir -p "$DIST_DIR"
if [[ -e "$APP_PATH" ]]; then
  rm -rf "$APP_PATH"
fi

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp -X "$PROJECT_ROOT/src/Info.plist" "$CONTENTS/Info.plist"
cp -X "$PROJECT_ROOT/src/launcher" "$CONTENTS/MacOS/launcher"
cp -X "$PROJECT_ROOT/src/downloader.command" "$CONTENTS/Resources/Instagram下载器.command"
cp -X "$PROJECT_ROOT/src/media_helper.py" "$CONTENTS/Resources/media_helper.py"
cp -X "$PROJECT_ROOT/assets/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

chmod +x "$CONTENTS/MacOS/launcher" \
  "$CONTENTS/Resources/Instagram下载器.command" \
  "$CONTENTS/Resources/media_helper.py"

xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

ZIP_PATH="$DIST_DIR/多平台媒体下载器-Mac.zip"
[[ -e "$ZIP_PATH" ]] && rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

print "已生成：$APP_PATH"
print "已生成：$ZIP_PATH"
