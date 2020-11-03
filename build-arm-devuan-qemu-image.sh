#!/bin/sh

SUITE=beowulf # or chimaera or ceres
ARCH=arm64 # or armhf or armel
IMGFILE=/var/tmp/devuan-${SUITE}-${ARCH}.img
LOOPDEV=`losetup -f`
GIGABYTES=10 # total size in GB
SWAPGB=1 # swap size in GB
ROOTFS=btrfs # or ext4
MMVARIANT=apt # or required, important, or standard
NETWORK=ifupdown # or none or network-manager
MIRROR=http://deb.devuan.org/merged/
INITUDEVPKG=sysvinit-core,eudev
KEYRINGPKG=devuan-keyring
YOURHOSTNAME=arm-guest
KERNEL_CMDLINE='net.ifnames=0 consoleblank=0 rw'
GRUB_TIMEOUT=0

apt-get -q -y --no-install-recommends install binfmt-support qemu-user-static qemu-efi-arm qemu-efi-aarch64 mmdebstrap qemu-system-arm

. ./common-part.sh
