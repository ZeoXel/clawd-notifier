#!/bin/bash
# 反向清理 install.sh 的产物。
# 不会动 ~/.claude/settings.json —— 你需要手动把 hook 里调用 claude_notify.sh 的地方还原回去。

set -u

APPS_DIR="${HOME}/Applications"
BIN_DIR="${HOME}/bin"

echo "==> 删除 ClaudeNotifier-*.app"
shopt -s nullglob
for app in "$APPS_DIR"/ClaudeNotifier-*.app; do
    rm -rf "$app"
    echo "    - $(basename "$app")"
done
shopt -u nullglob

echo "==> 删除 wrapper"
if [ -f "$BIN_DIR/claude_notify.sh" ]; then
    rm -f "$BIN_DIR/claude_notify.sh"
    echo "    - $BIN_DIR/claude_notify.sh"
fi

echo "==> 清图标缓存"
find /private/var/folders -path "*/com.apple.iconservices*" -prune -exec rm -rf {} + 2>/dev/null || true
killall Dock NotificationCenter 2>/dev/null || true

echo
echo "完成。如果你之前在 ~/.claude/settings.json 里挂了 claude_notify.sh，记得手动还原。"
