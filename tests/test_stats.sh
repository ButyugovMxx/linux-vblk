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
    echo "[test_stats] FAIL: $*"
    echo "[test_stats] recent dmesg:"
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

DMESG_BEFORE="$(dmesg | wc -l)"

echo "[test_stats] inserting module"
insmod "${MODULE_PATH}"

if [[ ! -e "${MAPPER}" ]]; then
    fail "${MAPPER} does not exist"
fi

if [[ ! -e "${UNMAPPER}" ]]; then
    fail "${UNMAPPER} does not exist"
fi

echo "[test_stats] mapping device"
if ! printf '%s\n' "${BACK_DEV}" > "${MAPPER}"; then
    fail "failed to map ${BACK_DEV}"
fi

sleep 0.5

if [[ ! -b "${VBLK_DEV}" ]]; then
    fail "${VBLK_DEV} was not created"
fi

TMP_DIR="$(mktemp -d)"
PAYLOAD="${TMP_DIR}/payload.bin"

printf 'STATTEST' > "${PAYLOAD}"

echo "[test_stats] doing write"
dd if="${PAYLOAD}" of="${VBLK_DEV}" bs=8 count=1 conv=notrunc,fsync status=none

echo "[test_stats] doing read"
dd if="${VBLK_DEV}" of=/dev/null bs=8 count=1 status=none

sync

echo "[test_stats] unmapping device"
if ! printf '1\n' > "${UNMAPPER}"; then
    fail "failed to unmap device"
fi

sleep 0.5

DMESG_AFTER="$(dmesg | tail -n +"${DMESG_BEFORE}")"

if ! echo "${DMESG_AFTER}" | grep -q 'stats:'; then
    fail "stats were not printed to dmesg"
fi

if ! echo "${DMESG_AFTER}" | grep -q 'reads='; then
    fail "reads counter was not printed"
fi

if ! echo "${DMESG_AFTER}" | grep -q 'writes='; then
    fail "writes counter was not printed"
fi

echo "[test_stats] PASS"