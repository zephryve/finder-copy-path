#!/bin/bash
# Finder Copy Path 安装脚本

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICES_DIR="$HOME/Library/Services"

mkdir -p "$SERVICES_DIR"

# 移除旧版本（如有）
rm -rf "$SERVICES_DIR/复制绝对路径.workflow"
rm -rf "$SERVICES_DIR/复制相对路径.workflow"

# 安装
cp -r "$SCRIPT_DIR/workflows/复制绝对路径.workflow" "$SERVICES_DIR/"
cp -r "$SCRIPT_DIR/workflows/复制相对路径.workflow" "$SERVICES_DIR/"

# 刷新系统服务缓存
/System/Library/CoreServices/pbs -flush 2>/dev/null

echo "安装完成。"
echo ""
echo "右键文件 → 快速操作 → 即可看到："
echo "  - 复制绝对路径"
echo "  - 复制相对路径"
echo ""
echo "如果没有出现，请注销重新登录。"
