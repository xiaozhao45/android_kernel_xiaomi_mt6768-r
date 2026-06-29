#!/bin/bash
# DroidSpaces Non-GKI Patches Application Script
# Downloads and applies patches from ravindu644/Droidspaces-OSS

KERNEL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_DIR="${KERNEL_ROOT}/.droidspaces_patches"

echo "=== DroidSpaces Patches Application Script ==="
echo "Kernel root: ${KERNEL_ROOT}"

mkdir -p "${PATCH_DIR}"

PATCH_BASE_URL="https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/main/Documentation/resources/kernel-patches/non-GKI"

# ---- Download patches ----
echo "[INFO] Downloading DroidSpaces non-GKI patches..."

curl -sL --fail "${PATCH_BASE_URL}/01.fix_kernel_panic_in_xt_qtaguid.patch" \
    -o "${PATCH_DIR}/01_fix_xt_qtaguid.patch" || {
    echo "[ERROR] Failed to download patch 01 (xt_qtaguid)"
    exit 1
}

curl -sL --fail "${PATCH_BASE_URL}/02.fix_restore%20cgroup%20file%20prefix%20handling%20.patch" \
    -o "${PATCH_DIR}/02_fix_cgroup_prefix.patch" || {
    echo "[ERROR] Failed to download patch 02 (cgroup prefix)"
    exit 1
}

echo "[INFO] Patches downloaded."

# ---- Apply patches ----
cd "${KERNEL_ROOT}"

apply_patch() {
    local patch_file="$1"
    local patch_name
    patch_name="$(basename "${patch_file}")"

    if [ ! -f "${patch_file}" ]; then
        echo "[WARN] Patch file not found: ${patch_file}"
        return 1
    fi

    echo "[INFO] Applying patch: ${patch_name}"

    if patch -p1 --dry-run < "${patch_file}" > /dev/null 2>&1; then
        patch -p1 < "${patch_file}"
        echo "[INFO] Applied successfully: ${patch_name}"
        return 0
    else
        echo "[WARN] Dry-run failed for ${patch_name}, may already be applied or has conflicts"
        # Try with --reverse to check if already applied
        if patch -p1 --reverse --dry-run < "${patch_file}" > /dev/null 2>&1; then
            echo "[INFO] Patch already applied: ${patch_name}"
            return 0
        fi
        echo "[WARN] Attempting to apply with --force..."
        patch -p1 --force < "${patch_file}" || {
            echo "[WARN] Patch skipped (conflicts): ${patch_name}"
            return 1
        }
    fi
}

FAIL_COUNT=0
for patch_file in "${PATCH_DIR}"/*.patch; do
    apply_patch "${patch_file}" || FAIL_COUNT=$((FAIL_COUNT + 1))
done

if [ "${FAIL_COUNT}" -gt 0 ]; then
    echo "[WARN] ${FAIL_COUNT} patch(es) had issues"
fi

echo "=== DroidSpaces patches application complete ==="
