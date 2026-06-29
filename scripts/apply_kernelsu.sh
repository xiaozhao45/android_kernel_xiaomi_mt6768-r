#!/bin/bash
# KernelSU Integration Script (backslashxx/KernelSU v3.2.5+)
# Compatible with non-GKI kernels including 4.14
# Installs to drivers/kernelsu via symlink + Kconfig/Makefile in drivers/

set -e

KERNEL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KSU_REPO="https://github.com/backslashxx/KernelSU.git"
# v3.2.5-4 is the latest tag in backslashxx fork
KSU_TAG="${1:-v3.2.5-4}"

echo "=== KernelSU Integration Script (backslashxx fork) ==="
echo "Kernel root: ${KERNEL_ROOT}"
echo "KSU tag:     ${KSU_TAG}"

# ---- Step 1: Clone or update KernelSU ----
if [ -d "${KERNEL_ROOT}/KernelSU" ]; then
    echo "[INFO] KernelSU directory exists, updating..."
    cd "${KERNEL_ROOT}/KernelSU"
    git fetch --all --tags
    git checkout "${KSU_TAG}" 2>/dev/null || {
        echo "[WARN] Tag ${KSU_TAG} not found, staying on current branch"
    }
    cd "${KERNEL_ROOT}"
else
    echo "[INFO] Cloning backslashxx/KernelSU..."
    git clone "${KSU_REPO}" "${KERNEL_ROOT}/KernelSU"
    cd "${KERNEL_ROOT}/KernelSU"
    git checkout "${KSU_TAG}" 2>/dev/null || {
        echo "[WARN] Tag ${KSU_TAG} not found, using default branch"
    }
    cd "${KERNEL_ROOT}"
fi

echo "[INFO] KernelSU version: $(cd "${KERNEL_ROOT}/KernelSU" && git describe --tags --always 2>/dev/null)"

# ---- Step 2: Determine driver directory ----
if [ -d "${KERNEL_ROOT}/common/drivers" ]; then
    DRIVER_DIR="${KERNEL_ROOT}/common/drivers"
elif [ -d "${KERNEL_ROOT}/drivers" ]; then
    DRIVER_DIR="${KERNEL_ROOT}/drivers"
else
    echo "[ERROR] drivers/ directory not found!"
    exit 1
fi

DRIVER_MAKEFILE="${DRIVER_DIR}/Makefile"
DRIVER_KCONFIG="${DRIVER_DIR}/Kconfig"

echo "[INFO] Driver dir: ${DRIVER_DIR}"

# ---- Step 3: Create symlink ----
if [ -L "${DRIVER_DIR}/kernelsu" ]; then
    rm -f "${DRIVER_DIR}/kernelsu"
    echo "[INFO] Removed old symlink"
fi

ln -sf "$(realpath --relative-to="${DRIVER_DIR}" "${KERNEL_ROOT}/KernelSU/kernel")" \
    "${DRIVER_DIR}/kernelsu"
echo "[INFO] Symlink created: drivers/kernelsu -> KernelSU/kernel"

# ---- Step 4: Add to drivers/Makefile ----
if ! grep -q "kernelsu" "${DRIVER_MAKEFILE}" 2>/dev/null; then
    printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "${DRIVER_MAKEFILE}"
    echo "[INFO] Added kernelsu to ${DRIVER_MAKEFILE}"
else
    echo "[INFO] kernelsu already in ${DRIVER_MAKEFILE}"
fi

# ---- Step 5: Add to drivers/Kconfig ----
if ! grep -q 'source "drivers/kernelsu/Kconfig"' "${DRIVER_KCONFIG}" 2>/dev/null; then
    # Insert before the last 'endmenu' if present, otherwise append
    if grep -q "^endmenu" "${DRIVER_KCONFIG}"; then
        sed -i '/^endmenu/i\source "drivers/kernelsu/Kconfig"' "${DRIVER_KCONFIG}"
    else
        printf '\nsource "drivers/kernelsu/Kconfig"\n' >> "${DRIVER_KCONFIG}"
    fi
    echo "[INFO] Added kernelsu Kconfig source to ${DRIVER_KCONFIG}"
else
    echo "[INFO] kernelsu Kconfig already sourced in ${DRIVER_KCONFIG}"
fi

echo "=== KernelSU integration complete ==="
