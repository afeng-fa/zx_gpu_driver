#!/bin/bash
# Copyright (C) 2026 afeng-fa
# Licensed under the GNU General Public License v3.0 (GPL-3.0)
# 兆芯 GPU 驱动回滚脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/回滚点"

if [ "$EUID" -ne 0 ]; then
    echo "请用 sudo 运行：sudo ./回滚.sh"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "错误：回滚点不存在：$BACKUP_DIR"
    exit 1
fi

echo "=== 回滚操作 ==="

# 卸载模块
echo "卸载 zx 模块..."
rmmod zx 2>/dev/null || true
rmmod zx_core 2>/dev/null || true

# 删除开机自动加载
echo "删除开机自动加载..."
rm -f /etc/modules-load.d/zx.conf

# 恢复 modprobe 配置
echo "恢复 modprobe 配置..."
rm -f /etc/modprobe.d/zx_gfx.conf

# 恢复 Xorg 配置
echo "恢复 Xorg 配置..."
rm -f /usr/share/X11/xorg.conf.d/10-zxgpu.conf

# 删除编译产物
echo "清理编译产物..."
KERNEL=$(cat "$BACKUP_DIR/kernel.txt" 2>/dev/null || uname -r)
rm -f /lib/modules/$KERNEL/updates/zx.ko
rm -f /lib/modules/$KERNEL/updates/zx_core.ko
depmod -a

# 删除用户态组件（可选，按需取消注释）
# echo "删除用户态组件..."
# dpkg --purge zhaoxin-linux-graphics-driver-dri 2>/dev/null || true

echo "=== 回滚完成 ==="
echo "请重启机器"
