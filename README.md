# 兆芯 KX-6000 C-960 (3A04) GPU 驱动一键部署包

## 版权说明

### 原始驱动

- **来源**: Zhaoxin Linux Graphics Driver (`zhaoxin-linux-graphics-driver-dri-glvnd_21.00.90_amd64.deb`)
- **原始版权**: Copyright (C) VIA Technologies, Inc., S3 Graphics Co., Ltd., Shanghai Zhaoxin Semiconductor Co., Ltd.
- **许可证**: GNU General Public License v3.0 (GPL-3.0)
- **源码位置**: DEB 包内 `/usr/src/zx-21.00.90/`（116 个内核模块源文件）

### 本项目修改

- **贡献者**: afeng-fa
- **修改内容**:
  - 为联想开天 N89Z-G1d（Ubuntu 24.04，内核 6.6.x）创建一键部署脚本
  - 编写自动化安装、验证、回滚工具
  - 补充问题分析文档和硬件兼容性说明
  - 优化驱动加载配置和用户态组件集成
- **许可证**: 本项目所有新增脚本、文档和配置文件遵循 GPL-3.0

> 本项目基于兆芯官方驱动进行适配，原始驱动版权归 VIA Technologies, Inc., S3 Graphics Co., Ltd., Shanghai Zhaoxin Semiconductor Co., Ltd. 所有。本项目贡献者的版权仅适用于新增的脚本、文档和修改部分。

## 适用场景

联想开天 N89Z-G1d，Ubuntu 24.04，内核 6.6.x，无网络环境。

## 问题描述

目标机 GPU PCI ID 为 `1d17:3a04`（兆芯 KX-6000 C-960），Ubuntu 默认不识别此设备，需要安装兆芯官方 zx 驱动。

**现象**：lspci 能看到 GPU，但无 Kernel driver in use，无硬件加速。

## 关键结论（踩坑记录）

1. **arise 驱动不支持 3A04**：arise.ko 的 PCI ID 表只有 `3D00` 系列，`3A04` 是完全不同的 GPU 家族（CHX002 vs Arise）
2. **正确驱动是 zx.ko**：`modinfo zx.ko` 确认包含 `pci:v00001D17d00003A04` alias
3. **不要强制指定 GBM/EGL/GL backend**：让 GLVND 自动选择，强制指定会导致 GLVND fallback 失效
4. **libGLX_zx.so.0 缺少 glXGetProcAddressARB**：与 libGLX.so.0 冲突，不能 symlink

## 文件结构

    zx_gpu_兆芯驱动/
    ├── 一键安装.sh              # 一键安装脚本（无网络）
    ├── 验证.sh                  # 安装后验证脚本
    ├── 回滚.sh                  # 一键回滚脚本
    ├── 驱动源码/
    │   └── zhaoxin-linux-graphics-driver-dri-glvnd_21.00.90_amd64.deb
    ├── 配置文件/
    │   ├── zx_gfx.conf          # /etc/modprobe.d/zx_gfx.conf
    │   └── 10-zxgpu.conf        # /usr/share/X11/xorg.conf.d/
    ├── 文档/
    │   ├── 问题分析.md           # 完整踩坑和根因分析
    │   └── 硬件兼容表.md         # PCI ID 与驱动映射关系
    └── 回滚点/
        └── (安装过程中自动生成)

## 使用方法

### 1. 传输到目标机

    scp -r zx_gpu_兆芯驱动/ qs@<TARGET_IP>:~/

### 2. 一键安装

    ssh qs@<TARGET_IP>
    cd ~/zx_gpu_兆芯驱动
    chmod +x 一键安装.sh
    ./一键安装.sh

### 3. 验证

    ./验证.sh

### 4. 如需回滚

    ./回滚.sh

## 前置条件

- Ubuntu 24.04
- 内核 6.6.x（已安装）
- build-essential 已安装（脚本会自动检查并安装）
- DEB 包已在 `驱动源码/` 目录中

## 原理简述

1. 兆芯 DEB 包包含完整内核模块源码（116 个 .c 文件）
2. 脚本在目标机上编译 `zx.ko` + `zx_core.ko`
3. 模块安装到 `/lib/modules/<kernel>/updates/` 并配置 `depmod`
4. 通过 `/etc/modules-load.d/zx.conf` 实现开机自动加载
5. 用户态组件（Xorg/EGL/GBM）从 DEB 包安装
6. **不强制指定 GPU backend**，由 GLVND 自动选择，避免 GL 问题
