#!/bin/bash
# clawd-notifier 安装脚本
#
# 做的事：
#   1. 校验 Homebrew + Pillow + terminal-notifier
#   2. 从 clawd-on-desk 抓 GIF（不打包进仓库，运行时下载）
#   3. 抽帧 → 合成奶白底 → 多分辨率 icns
#   4. 把 terminal-notifier.app fork 成 ClaudeNotifier-<pose>.app（每个 pose 一份）
#   5. lsregister 注册全部 bundle
#   6. 安装 wrapper 到 ~/bin/claude_notify.sh
#
# 不会自动改你的 ~/.claude/settings.json —— 安装结束会打印需要插入的 hook 片段。

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="${HOME}/Applications"
BIN_DIR="${HOME}/bin"
BUNDLE_PREFIX="${CLAWD_BUNDLE_PREFIX:-com.clawd.notifier}"
GIF_BASE_URL="${CLAWD_GIF_BASE_URL:-https://raw.githubusercontent.com/rullerzhou-afk/clawd-on-desk/main/assets/gif}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cyan()   { printf "\033[36m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }

cyan "==> 0/6 检查依赖"
command -v brew >/dev/null || { red "需要 Homebrew，先装：https://brew.sh"; exit 1; }

if ! command -v terminal-notifier >/dev/null; then
    yellow "    安装 terminal-notifier..."
    brew install terminal-notifier
fi

# 解析 terminal-notifier.app 路径（Cellar 真实位置）
TN_BIN="$(command -v terminal-notifier)"
SRC_APP=""
# 沿着 symlink + ../share/terminal-notifier/terminal-notifier.app 找
TN_REAL="$(readlink -f "$TN_BIN" 2>/dev/null || python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$TN_BIN")"
CANDIDATE="$(dirname "$TN_REAL")/../share/terminal-notifier/terminal-notifier.app"
if [ -d "$CANDIDATE" ]; then
    SRC_APP="$(cd "$CANDIDATE" && pwd)"
else
    # 兜底：直接 brew --prefix
    SRC_APP="$(brew --prefix terminal-notifier)/terminal-notifier.app"
fi
[ -d "$SRC_APP" ] || { red "找不到 terminal-notifier.app，brew 安装是否完成？"; exit 1; }
green "    terminal-notifier.app: $SRC_APP"

# Python Pillow（合成图像用）
# 系统 Python 在 macOS 14+ 走 PEP 668，禁止直接 pip install。
# 这里在临时 venv 里装一份，install 跑完随 $WORK_DIR 一起清掉，不污染用户 Python。
PYTHON_BIN=python3
if ! python3 -c "import PIL" 2>/dev/null; then
    yellow "    系统 Python 没有 Pillow，创建临时 venv..."
    VENV_DIR="$WORK_DIR/venv"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
    "$VENV_DIR/bin/pip" install --quiet Pillow
    PYTHON_BIN="$VENV_DIR/bin/python"
    green "    venv 就绪: $VENV_DIR"
fi

cyan "==> 1/6 读取 poses.txt"
POSES=()
while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo -n "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && POSES+=("$line")
done < "$REPO_DIR/poses.txt"
[ ${#POSES[@]} -gt 0 ] || { red "poses.txt 没有有效条目"; exit 1; }
green "    将构建 ${#POSES[@]} 个姿势：${POSES[*]}"

cyan "==> 2/6 下载 GIF（来自 clawd-on-desk）"
GIF_DIR="$WORK_DIR/gifs"
mkdir -p "$GIF_DIR"
for pose in "${POSES[@]}"; do
    url="$GIF_BASE_URL/clawd-${pose}.gif"
    out="$GIF_DIR/clawd-${pose}.gif"
    if ! curl -fsSL -o "$out" "$url"; then
        red "    下载失败：$url"; exit 1
    fi
done
green "    完成"

cyan "==> 3/6 合成 PNG（奶白底，nearest-neighbor 放大）"
PNG_DIR="$WORK_DIR/pngs"
mkdir -p "$PNG_DIR"
for pose in "${POSES[@]}"; do
    "$PYTHON_BIN" "$REPO_DIR/lib/compose_icon.py" \
        "$GIF_DIR/clawd-${pose}.gif" \
        "$PNG_DIR/clawd-${pose}.png"
done
green "    完成"

cyan "==> 4/6 fork bundle 到 $APPS_DIR"
mkdir -p "$APPS_DIR"
chmod +x "$REPO_DIR/lib/build_bundle.sh"
for pose in "${POSES[@]}"; do
    "$REPO_DIR/lib/build_bundle.sh" \
        "$SRC_APP" \
        "$pose" \
        "$PNG_DIR/clawd-${pose}.png" \
        "$APPS_DIR" \
        "$BUNDLE_PREFIX" >/dev/null
    echo "    + ClaudeNotifier-${pose}.app"
done
green "    完成"

cyan "==> 5/6 LaunchServices 注册 + 清图标缓存"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
find /private/var/folders -path "*/com.apple.iconservices*" -prune -exec rm -rf {} + 2>/dev/null || true
for pose in "${POSES[@]}"; do
    "$LSREG" -f "$APPS_DIR/ClaudeNotifier-${pose}.app"
done
killall Dock NotificationCenter 2>/dev/null || true
green "    完成"

cyan "==> 6/6 安装 wrapper 到 $BIN_DIR/claude_notify.sh"
mkdir -p "$BIN_DIR"
cp "$REPO_DIR/claude_notify.sh" "$BIN_DIR/claude_notify.sh"
chmod +x "$BIN_DIR/claude_notify.sh"
green "    完成"

echo
green "✓ 安装完成"
echo
cyan "==> 首次授权（一次性）"
echo "    macOS 通知权限按 bundle 授权——${#POSES[@]} 个 Clawd pose = ${#POSES[@]} 次「允许」。"
echo "    现在给每个 bundle 各发一发预热通知，请在弹窗出现时连续点击「允许」"
echo "    把这一波集中处理掉。授权过后未来不会再问。"
echo
if [ -t 0 ]; then
    read -p "    按 Enter 开始（Ctrl+C 跳过，留到第一次自然触发时再处理）..." _ || true
    for pose in "${POSES[@]}"; do
        "$APPS_DIR/ClaudeNotifier-${pose}.app/Contents/MacOS/terminal-notifier" \
            -title "Clawd Notifier" \
            -subtitle "首次授权" \
            -message "$pose" \
            >/dev/null 2>&1 &
        sleep 1
    done
    wait
    green "    预热完成。错过的弹窗：系统设置 → 通知 → 找 'Claude Code' 条目逐个开启。"
else
    yellow "    非交互式 shell，跳过预热。首次实际通知时会逐个弹授权框。"
fi
echo
cyan "测试一下："
echo "    ~/bin/claude_notify.sh -title 'Claude Code' -subtitle 'test' -message '随机姿势'"
echo
cyan "接入 Claude Code（手动编辑 ~/.claude/settings.json）："
cat "$REPO_DIR/examples/settings.snippet.json"
echo
yellow "注意：~/bin 需要在 PATH 里，或者在 settings.json 里写绝对路径 \$HOME/bin/claude_notify.sh"
