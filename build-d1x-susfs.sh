#!/bin/bash
# =============================================================================
# d1x (SM-N971N, Exynos 9825) 内核：KernelSU-Next + SUSFS v2.0.0
#
# 用法:  bash build-d1x-susfs.sh [clean]
#   clean  加此参数会先删除 out-d1x 做全量编译（约 10 分钟）
#
# 产物:  out-d1x/arch/arm64/boot/Image
#        out-d1x/System.map
#
# 依赖:  clang（Android clang r596125 / 22.0.2 已验证），LLD，GNU make，python3
#        工具链不在 PATH 时，改下面的 TOOLCHAIN 变量即可
# =============================================================================
set -eu

TOOLCHAIN=${TOOLCHAIN:-/home/lenovo/toolchains/clang-r596125/bin}
OUT=${OUT:-out-d1x}
JOBS=${JOBS:-$(nproc)}
DEFCONFIG=exynos9820-d1x_defconfig

[ -x "$TOOLCHAIN/clang" ] || { echo "找不到 clang: $TOOLCHAIN"; exit 1; }
export PATH="$TOOLCHAIN:$PATH"

MK="make -j$JOBS O=$OUT ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 KCFLAGS=-Wno-error"

[ "${1:-}" = "clean" ] && rm -rf "$OUT"

echo "=== 1/2 defconfig ==="
$MK $DEFCONFIG
echo "--- SUSFS 开关 ---"
grep -E '^CONFIG_KSU' "$OUT/.config" | sed 's/^/  /'

echo "=== 2/2 编译 Image ==="
START=$(date +%s)
$MK Image
echo "耗时 $(( $(date +%s) - START )) 秒"

IMG="$OUT/arch/arm64/boot/Image"
echo
echo "=== 产物 ==="
ls -l "$IMG"
echo "  sha256: $(sha256sum "$IMG" | cut -d' ' -f1)"
strings "$IMG" | grep -m1 '^Linux version' | sed 's/^/  /'
echo "  System.map 中 susfs 符号: $(grep -c susfs "$OUT/System.map")"
