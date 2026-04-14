# linux-vblk

Bio-based virtual block device driver for Linux kernel over one backend block device.

Developed on Fedora Server 43 with kernel `6.18.5-200.fc43.x86_64`.

## Build module

Run from the repository directory:

```bash
make
```

## Load module

```bash
sudo insmod vblk.ko
```

## Prepare backend disk

Create a loop-backed block device for testing:

```bash
sudo modprobe loop
sudo mknod /dev/loop0 b 7 0 2>/dev/null || true
sudo chmod 660 /dev/loop0
sudo chgrp disk /dev/loop0

dd if=/dev/zero of=/root/disk.img bs=1M count=64
sudo losetup /dev/loop0 /root/disk.img
```

## Load virtual disk

Create the virtual block device over the backend disk:

```bash
echo -n "/dev/loop0" | sudo tee /sys/module/vblk/parameters/mapper > /dev/null
```

The virtual disk should appear as `vblk01`.

## Unload virtual disk

Remove the virtual block device:

```bash
echo -n "1" | sudo tee /sys/module/vblk/parameters/unmapper > /dev/null
```

## Unload module

```bash
sudo rmmod vblk
```
