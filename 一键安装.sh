#!/bin/bash
# Copyright (C) 2026 afeng-fa
# Licensed under the GNU General Public License v3.0 (GPL-3.0)
# 兆芯 KX-6000 C-960 (3A04) GPU 驱动一键安装脚本
# 适用：Ubuntu 24.04 / 内核 6.6.x / 无网络环境
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEB_FILE="$SCRIPT_DIR/驱动源码/zhaoxin-linux-graphics-driver-dri-glvnd_21.00.90_amd64.deb"
BACKUP_DIR="$SCRIPT_DIR/回滚点"
LOG_FILE="$SCRIPT_DIR/install.log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# 检查 root
if [ "$EUID" -ne 0 ]; then
    echo "请用 sudo 运行：sudo ./一键安装.sh"
    exit 1
fi

# 检查 DEB
if [ ! -f "$DEB_FILE" ]; then
    echo "错误：DEB 文件不存在：$DEB_FILE"
    exit 1
fi

log "=== 开始安装 ==="

# ── Step 0: 创建回滚点 ──
log "[0/6] 创建回滚点..."
mkdir -p "$BACKUP_DIR"
cp /etc/default/grub "$BACKUP_DIR/grub.backup" 2>/dev/null || true
cp /etc/fstab "$BACKUP_DIR/fstab.backup" 2>/dev/null || true
uname -r > "$BACKUP_DIR/kernel.txt"
ls /boot/vmlinuz* > "$BACKUP_DIR/kernels.txt"
lsmod > "$BACKUP_DIR/modules.txt"
ls /etc/modules-load.d/ > "$BACKUP_DIR/modules_load_d.txt"
ls /etc/modprobe.d/*.conf > "$BACKUP_DIR/modprobe_d.txt" 2>/dev/null || true
ls /usr/share/X11/xorg.conf.d/ > "$BACKUP_DIR/xorg_conf_d.txt"
cat /etc/environment > "$BACKUP_DIR/environment.txt"
cat /etc/gdm3/custom.conf > "$BACKUP_DIR/gdm3.txt"
log "回滚点已保存到 $BACKUP_DIR"

# ── Step 1: 安装编译工具 ──
log "[1/6] 检查编译工具..."
if ! command -v gcc &>/dev/null; then
    log "安装 build-essential..."
    apt-get install -y build-essential
fi
log "gcc: $(gcc --version | head -1)"

# ── Step 2: 解压 DEB 获取源码 ──
log "[2/6] 解压 DEB..."
mkdir -p /tmp/zx_build
dpkg-deb -x "$DEB_FILE" /tmp/zx_build/
chmod -R 777 /tmp/zx_build/usr/src/zx-21.00.90/
log "源码路径：/tmp/zx_build/usr/src/zx-21.00.90/"

# ── Step 3: 编译内核模块 ──
log "[3/6] 编译内核模块..."
cd /tmp/zx_build/usr/src/zx-21.00.90
KERNEL=$(uname -r)
make -k -j$(nproc) \
    LINUXDIR=/usr/src/linux-headers-$KERNEL \
    -C /usr/src/linux-headers-$KERNEL \
    M=$(pwd) modules 2>&1 | tee -a "$LOG_FILE"
log "编译完成：zx.ko $(stat -c%s zx.ko) bytes, zx_core.ko $(stat -c%s zx_core.ko) bytes"

# ── Step 4: 安装模块到标准位置 ──
log "[4/6] 安装模块..."
mkdir -p /lib/modules/$KERNEL/updates
cp zx_core.ko /lib/modules/$KERNEL/updates/
cp zx.ko /lib/modules/$KERNEL/updates/
depmod -a
log "模块已安装到 /lib/modules/$KERNEL/updates/"

# ── Step 5: 配置开机自动加载 ──
log "[5/6] 配置开机自动加载..."
cat > /etc/modules-load.d/zx.conf << 'EOF'
zx_core
zx
EOF
log "已写入 /etc/modules-load.d/zx.conf"

# ── Step 6: 安装用户态组件 ──
log "[6/6] 安装用户态组件..."
dpkg --force-depends -i "$DEB_FILE" 2>&1 | tee -a "$LOG_FILE"
ldconfig
log "用户态组件安装完成"

# ── 安装 modprobe 配置 ──
cp "$SCRIPT_DIR/配置文件/zx_gfx.conf" /etc/modprobe.d/zx_gfx.conf
log "已安装 zx_gfx.conf"

# ── 安装 Xorg 配置 ──
cp "$SCRIPT_DIR/配置文件/10-zxgpu.conf" /usr/share/X11/xorg.conf.d/10-zxgpu.conf
log "已安装 10-zxgpu.conf"

# ── 验证编译产物 ──
log "=== 验证 ==="
modinfo /lib/modules/$KERNEL/updates/zx.ko | grep -E 'alias|vermagic'
ls -la /usr/lib/xorg/modules/drivers/zx_drv.so
ls -la /usr/lib/x86_64-linux-gnu/libEGL_zx.so.0
ls -la /usr/lib/x86_64-linux-gnu/gbm/zx_gbm.so

log "=== 安装完成 ==="
log "请重启机器以加载 zx 驱动"
log "重启后运行：cd $SCRIPT_DIR && sudo ./验证.sh"
