#!/bin/bash
# KernelSU Integration Script (backslashxx/KernelSU fork v3.2.5+)
# For non-GKI kernels (tested on 4.14)
#
# This script:
#   1. Clones backslashxx/KernelSU into the kernel tree
#   2. Creates symlink: drivers/kernelsu -> KernelSU/kernel
#   3. Patches drivers/Kconfig and drivers/Makefile
#
# Usage:
#   ./scripts/apply_kernelsu_backslashxx.sh [tag]
#   ./scripts/apply_kernelsu_backslashxx.sh --cleanup

set -eu

KSU_REPO="https://github.com/backslashxx/KernelSU.git"
KERNEL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

display_usage() {
    echo "Usage: $0 [--cleanup | <tag>]"
    echo "  --cleanup        Remove KernelSU integration"
    echo "  <tag>            Checkout specific tag (default: latest)"
    echo "  (no args)        Clone and integrate with latest tag"
}

initialize_variables() {
    if test -d "$KERNEL_ROOT/common/drivers"; then
        DRIVER_DIR="$KERNEL_ROOT/common/drivers"
    elif test -d "$KERNEL_ROOT/drivers"; then
        DRIVER_DIR="$KERNEL_ROOT/drivers"
    else
        echo '[ERROR] "drivers/" directory not found.'
        exit 1
    fi

    DRIVER_MAKEFILE="$DRIVER_DIR/Makefile"
    DRIVER_KCONFIG="$DRIVER_DIR/Kconfig"
}

perform_cleanup() {
    echo "[+] Cleaning up KernelSU (backslashxx)..."
    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    if grep -q "kernelsu" "$DRIVER_MAKEFILE" 2>/dev/null; then
        sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    fi
    if grep -q 'drivers/kernelsu/Kconfig' "$DRIVER_KCONFIG" 2>/dev/null; then
        sed -i '/drivers\/kernelsu\/Kconfig/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    fi
    if [ -d "$KERNEL_ROOT/KernelSU" ]; then
        rm -rf "$KERNEL_ROOT/KernelSU" && echo "[-] KernelSU directory deleted."
    fi
    echo "[+] Cleanup done."
}

setup_kernelsu() {
    local tag="${1:-}"

    echo "=== KernelSU Integration (backslashxx fork) ==="
    echo "[+] Kernel root: $KERNEL_ROOT"
    echo "[+] Driver dir:  $DRIVER_DIR"

    # Clone or update
    if [ -d "$KERNEL_ROOT/KernelSU" ]; then
        echo "[+] KernelSU directory exists, updating..."
        cd "$KERNEL_ROOT/KernelSU"
        git fetch --all --tags
    else
        echo "[+] Cloning $KSU_REPO ..."
        git clone "$KSU_REPO" "$KERNEL_ROOT/KernelSU"
        cd "$KERNEL_ROOT/KernelSU"
    fi

    # Checkout tag or latest
    if [ -n "$tag" ]; then
        echo "[+] Checking out $tag ..."
        git checkout "$tag" || { echo "[!] Tag $tag not found, staying on current branch"; }
    else
        echo "[+] Checking out latest tag ..."
        git checkout "$(git describe --abbrev=0 --tags 2>/dev/null || echo master)" || true
    fi

    KSU_VER="$(git describe --tags --always 2>/dev/null || echo unknown)"
    echo "[+] KernelSU version: $KSU_VER"
    cd "$KERNEL_ROOT"

    # Create symlink: drivers/kernelsu -> KernelSU/kernel
    if [ -L "$DRIVER_DIR/kernelsu" ]; then
        rm -f "$DRIVER_DIR/kernelsu"
    fi
    ln -sf "$(realpath --relative-to="$DRIVER_DIR" "$KERNEL_ROOT/KernelSU/kernel")" \
        "$DRIVER_DIR/kernelsu"
    echo "[+] Symlink: $DRIVER_DIR/kernelsu -> KernelSU/kernel"

    # Patch drivers/Makefile
    if ! grep -q "kernelsu" "$DRIVER_MAKEFILE" 2>/dev/null; then
        printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> "$DRIVER_MAKEFILE"
        echo "[+] Patched $DRIVER_MAKEFILE"
    else
        echo "[=] kernelsu already in Makefile"
    fi

    # Patch drivers/Kconfig (insert before endmenu)
    if ! grep -q 'drivers/kernelsu/Kconfig' "$DRIVER_KCONFIG" 2>/dev/null; then
        if grep -q "^endmenu" "$DRIVER_KCONFIG"; then
            sed -i '/^endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG"
        else
            printf '\nsource "drivers/kernelsu/Kconfig"\n' >> "$DRIVER_KCONFIG"
        fi
        echo "[+] Patched $DRIVER_KCONFIG"
    else
        echo "[=] kernelsu Kconfig already sourced"
    fi

    echo "=== KernelSU integration complete ($KSU_VER) ==="
}

# --- Main ---
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    display_usage
elif [ "${1:-}" = "--cleanup" ]; then
    initialize_variables
    perform_cleanup
else
    initialize_variables
    setup_kernelsu "${1:-}"
fi
