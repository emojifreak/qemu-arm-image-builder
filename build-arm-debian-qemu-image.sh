#!/bin/sh

SUITE=bullseye # buster or bullseye or sid
ARCH=arm64 # ppc64el or ppc64 or arm64 or armhf or armel or amd64 or i386
IMGFILE=/var/tmp/debian-${SUITE}-${ARCH}.img
LOOPDEV=`losetup -f`
GIGABYTES=5 # total size in GB
SWAPGB=1 # swap size in GB
ROOTFS=btrfs # or ext4
MMVARIANT=apt # or required, important, or standard
NETWORK=systemd-networkd # or ifupdown, network-manager, none
YOURHOSTNAME=arm-guest
KERNEL_CMDLINE='net.ifnames=0 consoleblank=0 rw'
GRUB_TIMEOUT=5
MIRROR=
INITUDEVPKG=systemd-sysv,udev # or sysvinit-core,udev
KEYRINGPKG=debian-archive-keyring

apt-get -q -y --no-install-recommends install binfmt-support qemu-user-static qemu-efi-arm qemu-efi-aarch64 mmdebstrap qemu-system-arm

. ./common-part.sh
