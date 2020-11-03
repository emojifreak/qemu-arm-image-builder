#!/bin/sh

SUITE=bullseye
ARCH=arm64 # or armhf or armel
IMGFILE=/var/tmp/debian-${SUITE}-${ARCH}.img
LOOPDEV=`losetup -f`
GIGABYTES=10 # total size in GB
SWAPGB=1 # swap size in GB
ROOTFS=btrfs # or ext4
MOUNTPT=/tmp/mnt$$
MMVARIANT=apt # or required, important, or standard
NETWORK=systemd-networkd # or ifupdown, network-manager, none
YOURHOSTNAME=arm-guest
KERNEL_CMDLINE='net.ifnames=0 consoleblank=0 rw'
GRUB_TIMEOUT=0
MIRROR=http://deb.debian.org/debian
INITUDEVPKG=systemd-sysv,udev # or sysvinit-core,udev
KEYRINGPKG=debian-archive-keyring

. ./common-part.sh
