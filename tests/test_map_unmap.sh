#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODULE_PATH="${ROOT_DIR}/vblk.ko"
BACK_DEV="/dev/loop0"
VBLK_DEV="/dev/vblk01"

MAPPER="/sys/module/vblk/parameters/mapper"
UNMAPPER="/sys/module/vblk/parameters/unmapper"

cleanup() {
    if [[ -e "${UNMAPPER}" ]]; then
        printf '1\n' > "${UNMAPPER}" 2>/dev/null || true
        sleep 0.2
    fi

    if lsmod | grep -q '^vblk\b'; then
        rmmod vblk 2>/dev/null || true
    fi

    "${ROOT_DIR}/scripts/cleanup_loop.sh" >/dev/null 2>&1 || true
}

trap cleanup EXIT

fail() {
    echo "[test_map_unmap] FAIL: $*"
    echo "[test_map_unmap] recent dmesg:"
    dmesg | tail -40
    exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
    fail "run as root"
fi

"${ROOT_DIR}/scripts/setup_loop.sh"

if [[ ! -b "${BACK_DEV}" ]]; then
    fail "${BACK_DEV} is not a block device"
fi

if ! losetup "${BACK_DEV}" >/dev/null 2>&1; then
    fail "${BACK_DEV} is not attached"
fi

echo "[test_map_unmap] inserting module"
insmod "${MODULE_PATH}"

if [[ ! -e "${MAPPER}" ]]; then
    fail "${MAPPER} does not exist"
fi

if [[ ! -e "${UNMAPPER}" ]]; then
    fail "${UNMAPPER} does not exist"
fi

echo "[test_map_unmap] mapping device"
if ! printf '%s\n' "${BACK_DEV}" > "${MAPPER}"; then
    fail "failed to map ${BACK_DEV}"
fi

sleep 0.5

if [[ ! -b "${VBLK_DEV}" ]]; then
    fail "${VBLK_DEV} was not created"
fi

echo "[test_map_unmap] unmapping device"
if ! printf '1\n' > "${UNMAPPER}"; then
    fail "failed to unmap device"
fi

sleep 0.5

if [[ -b "${VBLK_DEV}" ]]; then
    fail "${VBLK_DEV} still exists after unmap"
fi

echo "[test_map_unmap] PASS"