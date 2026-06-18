#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODULE_PATH="${ROOT_DIR}/vblk.ko"
BACK_DEV="/dev/loop0"
VBLK_DEV="/dev/vblk01"

MAPPER="/sys/module/vblk/parameters/mapper"
UNMAPPER="/sys/module/vblk/parameters/unmapper"

FIO_DIR="${ROOT_DIR}/scripts/fio"

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
    echo "[test_fio] FAIL: $*"
    echo "[test_fio] recent dmesg:"
    dmesg | tail -60
    exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
    fail "run as root"
fi

if ! command -v fio >/dev/null 2>&1; then
    fail "fio is not installed. Install it with: sudo dnf install -y fio"
fi

"${ROOT_DIR}/scripts/setup_loop.sh"

if [[ ! -b "${BACK_DEV}" ]]; then
    fail "${BACK_DEV} is not a block device"
fi

if ! losetup "${BACK_DEV}" >/dev/null 2>&1; then
    fail "${BACK_DEV} is not attached"
fi

DMESG_BEFORE="$(dmesg | wc -l)"

echo "[test_fio] inserting module"
insmod "${MODULE_PATH}"

if [[ ! -e "${MAPPER}" ]]; then
    fail "${MAPPER} does not exist"
fi

if [[ ! -e "${UNMAPPER}" ]]; then
    fail "${UNMAPPER} does not exist"
fi

echo "[test_fio] mapping device"
if ! printf '%s\n' "${BACK_DEV}" > "${MAPPER}"; then
    fail "failed to map ${BACK_DEV}"
fi

sleep 0.5

if [[ ! -b "${VBLK_DEV}" ]]; then
    fail "${VBLK_DEV} was not created"
fi

for fio_job in \
    "${FIO_DIR}/seq_rw_4k.fio" \
    "${FIO_DIR}/seq_rw_16k.fio" \
    "${FIO_DIR}/rand_rw_4k.fio" \
    "${FIO_DIR}/rand_rw_16k.fio"
do
    echo
    echo "----------------------------------------"
    echo "[test_fio] running ${fio_job}"
    echo "----------------------------------------"

    fio "${fio_job}"
done

sync

echo "[test_fio] unmapping device"
if ! printf '1\n' > "${UNMAPPER}"; then
    fail "failed to unmap device"
fi

sleep 0.5

DMESG_AFTER="$(dmesg | tail -n +"${DMESG_BEFORE}")"

if ! echo "${DMESG_AFTER}" | grep -q 'stats:'; then
    fail "stats were not printed to dmesg"
fi

if ! echo "${DMESG_AFTER}" | grep -q 'errors=0'; then
    fail "fio workload finished, but driver stats contain errors"
fi

echo "[test_fio] PASS"