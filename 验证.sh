#!/bin/bash
# Copyright (C) 2026 afeng-fa
# Licensed under the GNU General Public License v3.0 (GPL-3.0)
# 兆芯 GPU 驱动验证脚本
ERRORS=0

check() {
    if eval "$2" &>/dev/null; then
        echo "✅ $1"
    else
        echo "❌ $1"
        ERRORS=$((ERRORS+1))
    fi
}

echo "=== 兆芯 GPU 驱动验证 ==="
echo "内核: $(uname -r)"
echo ""

check "内核模块 zx 已加载" "lsmod | grep -q '^zx '"
check "内核模块 zx_core 已加载" "lsmod | grep -q 'zx_core'"
check "GPU 绑定 zx 驱动" "lspci -nnk 2>/dev/null | grep -A3 'VGA' | grep -q 'Kernel driver in use: zx'"
check "DRM 设备存在" "[ -e /dev/dri/card0 ]"
check "Xorg zx 驱动" "[ -f /usr/lib/xorg/modules/drivers/zx_drv.so ]"
check "EGL zx 库" "[ -f /usr/lib/x86_64-linux-gnu/libEGL_zx.so.0 ]"
check "GBM zx 后端" "[ -f /usr/lib/x86_64-linux-gnu/gbm/zx_gbm.so ]"
check "DRI zx 驱动" "[ -f /usr/lib/x86_64-linux-gnu/dri/zx_drv_video.so ]"
check "EGL vendor 配置" "[ -f /usr/share/glvnd/egl_vendor.d/10_zx.json ]"
check "Xorg OutputClass" "[ -f /usr/share/X11/xorg.conf.d/10-zxgpu.conf ]"
check "modprobe 配置" "[ -f /etc/modprobe.d/zx_gfx.conf ]"
check "开机自动加载" "[ -f /etc/modules-load.d/zx.conf ]"

echo ""
echo "=== GPU 信息 ==="
lspci -nnk -s 00:01.0 2>/dev/null | grep -E 'driver|Kernel|alias'

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ 所有检查通过"
else
    echo "❌ 有 $ERRORS 项检查失败"
fi
