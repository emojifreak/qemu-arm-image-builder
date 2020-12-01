#!/bin/sh

SUITE=chimaera # beowulf or chimaera or ceres
ARCH=arm64 # ppc64el or arm64 or armhf or armel or amd64 or i386
IMGFILE=/var/tmp/devuan-${SUITE}-${ARCH}.img
GIGABYTES=10 # total size in GB
SWAPGB=1 # swap size in GB
ROOTFS=btrfs # btrfs or ext4
MMVARIANT=apt # apt or required, important, or standard
NETWORK=ifupdown # ifupdown or none or network-manager
MIRROR=http://deb.devuan.org/merged/
INITUDEVPKG=sysvinit-core,eudev
KEYRINGPKG=devuan-keyring
YOURHOSTNAME=arm-guest
KERNEL_CMDLINE='net.ifnames=0 consoleblank=0 rw'
GRUB_TIMEOUT=5

apt-get -q -y --no-install-recommends install binfmt-support qemu-user-static qemu-efi-arm qemu-efi-aarch64 mmdebstrap qemu-system-arm ipxe-qemu

MOUNTPT=/tmp/mnt$$
LOOPDEV=`losetup -f`
if [ -z "${LOOPDEV}" -o ! -e "${LOOPDEV}" ]; then
  echo "losetup -f failed to find an unused loop device, exiting ..."
  echo "Consider rmmod -f loop; modprobe loop"
  exit 1
fi

. ./common-part.sh
. ./common-part2.sh

if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  umount -f ${MOUNTPT}/boot/efi
fi
umount -f ${MOUNTPT}
rm -rf ${MOUNTPT}
losetup -d ${LOOPDEV}
