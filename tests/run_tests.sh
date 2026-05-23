#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cleanup() {
    echo "[run_tests] cleanup"

    if [[ -e /sys/module/vblk/parameters/unmapper ]]; then
        printf '1\n' > /sys/module/vblk/parameters/unmapper 2>/dev/null || true
        sleep 0.2
    fi

    if lsmod | grep -q '^vblk\b'; then
        rmmod vblk 2>/dev/null || true
    fi

    if [[ -x "${ROOT_DIR}/scripts/cleanup_loop.sh" ]]; then
        "${ROOT_DIR}/scripts/cleanup_loop.sh" || true
    fi
}

trap cleanup EXIT

if [[ "${EUID}" -ne 0 ]]; then
    echo "[run_tests] error: tests must be run as root"
    echo "[run_tests] run: sudo bash tests/run_tests.sh"
    exit 1
fi

cd "${ROOT_DIR}"

echo "[run_tests] running tests"

for test_script in \
    tests/test_map_unmap.sh \
    tests/test_read_write.sh \
    tests/test_stats.sh \
    tests/test_fio.sh
do
    echo
    echo "========================================"
    echo "[run_tests] running ${test_script}"
    echo "========================================"

    cleanup
    bash "${test_script}"
    cleanup

    echo "[run_tests] passed ${test_script}"
done

echo
echo "[run_tests] all tests passed"