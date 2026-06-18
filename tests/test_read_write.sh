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

    if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}

trap cleanup EXIT

fail() {
    echo "[test_read_write] FAIL: $*"
    echo "[test_read_write] recent dmesg:"
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

echo "[test_read_write] inserting module"
insmod "${MODULE_PATH}"

if [[ ! -e "${MAPPER}" ]]; then
    fail "${MAPPER} does not exist"
fi

if [[ ! -e "${UNMAPPER}" ]]; then
    fail "${UNMAPPER} does not exist"
fi

echo "[test_read_write] mapping device"
if ! printf '%s\n' "${BACK_DEV}" > "${MAPPER}"; then
    fail "failed to map ${BACK_DEV}"
fi

sleep 0.5

if [[ ! -b "${VBLK_DEV}" ]]; then
    fail "${VBLK_DEV} was not created"
fi

TMP_DIR="$(mktemp -d)"
PAYLOAD="${TMP_DIR}/payload.bin"
FROM_VBLK="${TMP_DIR}/from_vblk.bin"
FROM_BACK="${TMP_DIR}/from_back.bin"

printf 'HELLO123' > "${PAYLOAD}"

echo "[test_read_write] writing sample data"
dd if="${PAYLOAD}" of="${VBLK_DEV}" bs=8 count=1 conv=notrunc,fsync status=none

sync
blockdev --flushbufs "${VBLK_DEV}" || true
blockdev --flushbufs "${BACK_DEV}" || true

echo "[test_read_write] reading back from virtual device"
dd if="${VBLK_DEV}" of="${FROM_VBLK}" bs=8 count=1 status=none

if ! cmp -s "${PAYLOAD}" "${FROM_VBLK}"; then
    echo "[test_read_write] expected:"
    od -An -tx1 -c "${PAYLOAD}"
    echo "[test_read_write] actual:"
    od -An -tx1 -c "${FROM_VBLK}"
    fail "wrong data from ${VBLK_DEV}"
fi

echo "[test_read_write] reading back from backend"
dd if="${BACK_DEV}" of="${FROM_BACK}" bs=8 count=1 status=none

if ! cmp -s "${PAYLOAD}" "${FROM_BACK}"; then
    echo "[test_read_write] expected:"
    od -An -tx1 -c "${PAYLOAD}"
    echo "[test_read_write] actual:"
    od -An -tx1 -c "${FROM_BACK}"
    fail "wrong data from ${BACK_DEV}"
fi

echo "[test_read_write] unmapping device"
if ! printf '1\n' > "${UNMAPPER}"; then
    fail "failed to unmap device"
fi

sleep 0.5

echo "[test_read_write] PASS"