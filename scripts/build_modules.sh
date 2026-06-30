#!/bin/bash
# Build kernel modules only
# Usage: ./scripts/build_modules.sh [device]
# Example: ./scripts/build_modules.sh lancelot

set -euo pipefail

DEVICE="${1:-lancelot}"
DEFCONFIG="arch/arm64/configs/${DEVICE}_defconfig"
FRAGMENT="scripts/kernelsu_backslashxx_config.fragment"
OUT_DIR="out"
MODULES_OUT="modules_output/${DEVICE}"

# --- Toolchain ---
export ARCH=arm64
export LLVM=1
export CC="ccache clang"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
export LD_COMPAT=arm-linux-gnueabi-ld
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export CLANG_TRIPLE=aarch64-linux-gnu-

MAKE_ARGS=(
    O="${OUT_DIR}"
    ARCH=arm64
    LLVM=1
    CC="ccache clang"
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    LD_COMPAT=arm-linux-gnueabi-ld
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    CLANG_TRIPLE=aarch64-linux-gnu-
)

# --- Validate ---
if [ ! -f "$DEFCONFIG" ]; then
    echo "ERROR: Defconfig not found: $DEFCONFIG"
    exit 1
fi

# --- Merge config fragment ---
echo "=== Merging config fragment ==="
{
    echo ""
    echo "# =========================================="
    echo "# backslashxx/KernelSU + DroidSpaces"
    echo "# Auto-added by build_modules.sh"
    echo "# =========================================="
    cat "$FRAGMENT"
} >> "$DEFCONFIG"

# Remove "# CONFIG_xxx is not set" for configs we're enabling
while IFS= read -r line; do
    cfg=$(echo "$line" | grep -oP '^CONFIG_\w+' || true)
    [ -n "$cfg" ] && sed -i "/# ${cfg} is not set/d" "$DEFCONFIG"
done < "$FRAGMENT"

# --- Configure ---
echo "=== Configuring (${DEVICE}_defconfig) ==="
mkdir -p "${OUT_DIR}"
make -j$(nproc) "${MAKE_ARGS[@]}" "${DEVICE}_defconfig"

# --- Build kernel (required for Module.symvers) ---
echo "=== Building kernel ==="
make -j$(nproc) "${MAKE_ARGS[@]}" 2>&1 | tee build.log

# --- Build modules ---
echo "=== Building modules ==="
make -j$(nproc) "${MAKE_ARGS[@]}" modules

# --- Collect modules ---
echo "=== Collecting modules ==="
rm -rf "${MODULES_OUT}"
mkdir -p "${MODULES_OUT}"

cd "${OUT_DIR}"
find . -name "*.ko" -print0 | while IFS= read -r -d '' f; do
    dest="${MODULES_OUT}/${f#./}"
    mkdir -p "$(dirname "$dest")"
    cp "$f" "$dest"
done
cd ..

# Generate module list
find "${MODULES_OUT}" -name "*.ko" -printf '%P\n' | sort > "${MODULES_OUT}/modules.list"
MODULE_COUNT=$(wc -l < "${MODULES_OUT}/modules.list")

# Tar modules
tar -czf "${MODULES_OUT}/modules.tar.gz" -C "${MODULES_OUT}" --exclude='modules.tar.gz' --exclude='modules.list' .

echo ""
echo "=== Done ==="
echo "Modules: ${MODULE_COUNT}"
echo "Output: ${MODULES_OUT}/"
echo ""
cat "${MODULES_OUT}/modules.list"
