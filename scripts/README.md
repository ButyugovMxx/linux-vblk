# Tests

This directory contains integration tests for the `vblk` kernel module.

The tests build and load the kernel module, create a loop-backed block device,
map it through the `vblk` module, perform I/O operations, and check that the
driver behaves correctly.

## Test list

Current tests:

- `test_map_unmap.sh` — checks that the module can map and unmap a backing block device.
- `test_read_write.sh` — checks basic read/write operations through `/dev/vblk01`.
- `test_stats.sh` — checks that the driver prints I/O statistics after device usage.

## Run all tests

From the project root directory:

```bash
make test