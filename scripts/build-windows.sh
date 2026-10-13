#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
DIST="$ROOT/dist"
PACKAGE="$DIST/Media-Downloader-Windows"

mkdir -p "$DIST"
rm -rf "$PACKAGE" "$DIST/windows-media-downloader-v3.1.0.zip"
mkdir -p "$PACKAGE"
cp "$ROOT/windows/双击启动.cmd" "$PACKAGE/Start Downloader.cmd"
cp "$ROOT/windows/downloader.ps1" "$PACKAGE/"
cp "$ROOT/windows/media_helper.py" "$PACKAGE/"
cp "$ROOT/windows/使用说明.txt" "$PACKAGE/README.txt"

cd "$DIST"
/usr/bin/zip -qr "windows-media-downloader-v3.1.0.zip" "Media-Downloader-Windows"
print "已生成：$DIST/windows-media-downloader-v3.1.0.zip"
