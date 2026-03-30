#!/bin/bash
# Finder Copy Path - Install Script

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICES_DIR="$HOME/Library/Services"

mkdir -p "$SERVICES_DIR"

# 检测系统语言 / Detect system language
LANG_PREF=$(defaults read -g AppleLanguages 2>/dev/null | head -2 | tail -1 | tr -d ' ",')

if [[ "$LANG_PREF" == zh* ]]; then
    WORKFLOW_DIR="$SCRIPT_DIR/workflows/zh-CN"
    WF_ABS="复制绝对路径"
    WF_REL="复制相对路径"
else
    WORKFLOW_DIR="$SCRIPT_DIR/workflows/en"
    WF_ABS="Copy Absolute Path"
    WF_REL="Copy Relative Path"
fi

# 移除旧版本（中英文都清理）/ Remove old versions (both languages)
rm -rf "$SERVICES_DIR/复制绝对路径.workflow"
rm -rf "$SERVICES_DIR/复制相对路径.workflow"
rm -rf "$SERVICES_DIR/Copy Absolute Path.workflow"
rm -rf "$SERVICES_DIR/Copy Relative Path.workflow"

# 安装 / Install
cp -r "$WORKFLOW_DIR/$WF_ABS.workflow" "$SERVICES_DIR/"
cp -r "$WORKFLOW_DIR/$WF_REL.workflow" "$SERVICES_DIR/"

# 刷新系统服务缓存 / Flush system services cache
/System/Library/CoreServices/pbs -flush 2>/dev/null

if [[ "$LANG_PREF" == zh* ]]; then
    echo "安装完成。"
    echo ""
    echo "右键文件 → 快速操作 → 即可看到："
    echo "  - 复制绝对路径"
    echo "  - 复制相对路径"
    echo ""
    echo "如果没有出现，请注销重新登录。"
else
    echo "Installation complete."
    echo ""
    echo "Right-click a file → Quick Actions → You should see:"
    echo "  - Copy Absolute Path"
    echo "  - Copy Relative Path"
    echo ""
    echo "If they don't appear, log out and back in."
fi
