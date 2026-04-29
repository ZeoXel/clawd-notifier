#!/bin/bash
# 把 terminal-notifier.app fork 一份成 ClaudeNotifier-<pose>.app，
# 改写 CFBundleIdentifier，并把 Resources/Terminal.icns 替换成
# 多分辨率打包 (16/32/64/128/256/512/1024 + @2x) 的 icns。
#
# 用法:
#   build_bundle.sh <src_app> <pose> <icon_png> <dst_apps_dir> <bundle_id_prefix>

set -euo pipefail

SRC_APP="$1"
POSE="$2"
ICON_PNG="$3"
DST_APPS="$4"
PREFIX="$5"

DST="${DST_APPS}/ClaudeNotifier-${POSE}.app"
rm -rf "$DST"
cp -R "$SRC_APP" "$DST"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier ${PREFIX}.${POSE}" \
    "$DST/Contents/Info.plist"

# 多分辨率 icns
TMP=$(mktemp -d)
ICONSET="$TMP/icon.iconset"
mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512 1024; do
    sips -z $sz $sz "$ICON_PNG" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    if [ $sz -le 512 ]; then
        sz2=$((sz * 2))
        sips -z $sz2 $sz2 "$ICON_PNG" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
    fi
done
iconutil -c icns "$ICONSET" -o "$DST/Contents/Resources/Terminal.icns"
rm -rf "$TMP"

# 触摸 mtime，让 LaunchServices 视为更新
touch "$DST"

echo "$DST"
