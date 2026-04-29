#!/bin/bash
# clawd-notifier 运行时入口
# 从 ~/Applications/ClaudeNotifier-*.app 中随机抽一个调用 terminal-notifier
# 参数原样透传。
#
# 之所以走多 bundle 路线：macOS 通知图标在 bundle 级别缓存，
# 单个 .app 内换 icns 不会被通知中心实时识别。
# 给每个姿势一个独立 bundle ID，系统就能各自缓存、随机切换。

set -u

shopt -s nullglob
APPS=("$HOME"/Applications/ClaudeNotifier-*.app)
shopt -u nullglob

if [ ${#APPS[@]} -eq 0 ]; then
    # 还没安装 pose 池：回退到原始 ClaudeNotifier.app（如果存在的话）
    FALLBACK="$HOME/Applications/ClaudeNotifier.app/Contents/MacOS/terminal-notifier"
    if [ -x "$FALLBACK" ]; then
        exec "$FALLBACK" "$@"
    fi
    # 再回退到系统 PATH 上的 terminal-notifier
    exec terminal-notifier "$@"
fi

PICK="${APPS[$RANDOM % ${#APPS[@]}]}"
exec "$PICK/Contents/MacOS/terminal-notifier" "$@"
