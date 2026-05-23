#!/usr/bin/env bash
set -euo pipefail

LOOP_DEV="/dev/loop0"
BACKING_FILE="/root/disk.img"
BACKING_SIZE="64M"

log() {
    echo "[setup_loop] $*"
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "[setup_loop] FAIL: run as root"
    exit 1
fi

log "loading loop module"
modprobe loop

log "creating backing file ${BACKING_FILE} (${BACKING_SIZE})"
truncate -s "${BACKING_SIZE}" "${BACKING_FILE}"

if losetup "${LOOP_DEV}" >/dev/null 2>&1; then
    log "detaching previous ${LOOP_DEV}"
    losetup -d "${LOOP_DEV}" || true
    sleep 0.5
fi

log "attaching ${BACKING_FILE} -> ${LOOP_DEV}"
losetup "${LOOP_DEV}" "${BACKING_FILE}"

udevadm settle 2>/dev/null || true
sleep 0.5

if [[ ! -b "${LOOP_DEV}" ]]; then
    echo "[setup_loop] FAIL: ${LOOP_DEV} is not a block device"
    exit 1
fi

if ! losetup "${LOOP_DEV}" >/dev/null 2>&1; then
    echo "[setup_loop] FAIL: ${LOOP_DEV} is not attached"
    exit 1
fi

blockdev --getsize64 "${LOOP_DEV}" >/dev/null

log "done"