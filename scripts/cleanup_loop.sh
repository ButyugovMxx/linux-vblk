#!/usr/bin/env bash
set -euo pipefail

LOOP_DEV="/dev/loop0"

log() {
    echo "[cleanup_loop] $*"
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "[cleanup_loop] FAIL: run as root"
    exit 1
fi

if losetup "${LOOP_DEV}" >/dev/null 2>&1; then
    log "detaching ${LOOP_DEV}"
    losetup -d "${LOOP_DEV}" || true
    sleep 0.3
else
    log "${LOOP_DEV} is not attached"
fi