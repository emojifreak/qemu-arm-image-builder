#!/bin/sh

SUITE=sid # buster or bullseye or sid
ARCH=amd64 # ppc64el, ppc64, powerpc, arm64, armhf, amd64, or i386

GIGABYTES=25 # total size in GB
SWAPGB=0 # swap size in GB
ROOTFS=ext4 # btrfs or ext4
MMVARIANT=important # apt, required, important, or standard
YOURHOSTNAME=host
KERNEL_CMDLINE="net.ifnames=0 consoleblank=0 rw console=hvc0 console=ttyS0 console=ttyAMA0 console=tty0"
GRUB_TIMEOUT=0
MIRROR=http://deb.debian.org/debian/

INITUDEVPKG=systemd-sysv,udev,libpam-systemd,libnss-systemd,dbus-user-session,lsb-release
NETWORK=systemd-networkd # systemd-networkd or ifupdown, network-manager, none
KEYRINGPKG=debian-keyring,debian-archive-keyring,rng-tools,openssh-server,eatmydata,gpg,dpkg-dev,python3-minimal,apparmor-utils,sudo
# You can added apparmor-utils,selinux-utils to KEYRINGPKG

# For sysvinit as /sbin/init in Debian, use the following
# MMVARIANT must be required or apt
#INITUDEVPKG=sysvinit-core,udev,libpam-elogind,lsb-base,lsb-release
#NETWORK=ifupdown

#For Devuan, use the following
#MIRROR=http://deb.devuan.org/merged/
#SUITE=ceres # ceres, chimaera or beowulf
#KEYRINGPKG=devuan-keyring,debian-keyring,rng-tools,openssh-server,eatmydata,gpg,dpkg-dev,python3-minimal,sudo
#INITUDEVPKG=sysvinit-core,eudev,libpam-elogind,lsb-base,lsb-release
#NETWORK=ifupdown


#apt-get -q -y --no-install-recommends install binfmt-support qemu-user-static qemu-efi-arm qemu-efi-aarch64 mmdebstrap qemu-system-arm

IMGFILE=/var/tmp/autopkgtest-${SUITE}-${ARCH}.img
MOUNTPT=/tmp/mnt$$
LOOPDEV=`losetup -f`
if [ -z "${LOOPDEV}" -o ! -e "${LOOPDEV}" ]; then
  echo "losetup -f failed to find an unused loop device, exiting ..."
  echo "Consider rmmod -f loop; modprobe loop"
  exit 1
fi

if ! [ -e setup-testbed ]; then
 if ! wget -c 'https://salsa.debian.org/ci-team/autopkgtest/-/raw/master/setup-commands/setup-testbed'; then
   echo "Download failure..."
   exit 1
 fi
fi

. ./common-part.sh

chroot ${MOUNTPT} passwd --delete root
for u in user debci; do
  chroot ${MOUNTPT} useradd --groups sudo --home-dir /home/$u --create-home $u
  chroot ${MOUNTPT} passwd --delete $u
done
cat ${MOUNTPT}/etc/passwd

AUTOPKGTEST_KEEP_APT_SOURCES=1 AUTOPKGTEST_BUILD_QEMU=1 sh setup-testbed "$MOUNTPT"

if [ $ARCH != ppc64 -a $ARCH != powerpc ]; then
  cat << EOF >${MOUNTPT}/etc/apt/sources.list
deb $MIRROR $SUITE main contrib non-free
deb-src $MIRROR $SUITE main contrib non-free
EOF
else
  cat << EOF >${MOUNTPT}/etc/apt/sources.list
deb http://deb.debian.org/debian-ports/ sid main
deb-src http://deb.debian.org/debian/ sid main
deb http://deb.debian.org/debian-ports/ unreleased main
deb-src http://deb.debian.org/debian-ports/ unreleased main
EOF
fi
if [ $SUITE = sid ]; then
  cat << EOF >>${MOUNTPT}/etc/apt/sources.list
deb http://incoming.debian.org/debian-buildd buildd-sid main contrib non-free
deb-src http://incoming.debian.org/debian-buildd buildd-sid main contrib non-free
EOF
fi
chroot ${MOUNTPT} apt-get -y -q update
chroot ${MOUNTPT} apt-get -y -q --purge --autoremove dist-upgrade
chroot ${MOUNTPT} apt-get -y -q clean

if [ $ROOTFS = ext4 ]; then
  e4defrag ${MOUNTPT}  >/dev/null
elif [ $ROOTFS = btrfs ]; then
  btrfs filesystem defragment -r ${MOUNTPT}
fi
fstrim ${MOUNTPT}
  
if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  fstrim ${MOUNTPT}/boot/efi
  umount -f ${MOUNTPT}/boot/efi
fi
umount -f ${MOUNTPT}
rm -rf ${MOUNTPT}
if [ $ROOTFS = ext4 ]; then
  tune2fs -e panic -o journal_data_writeback,nobarrier,discard ${LOOPDEV}p2
fi
losetup -d ${LOOPDEV}
set -x
rm -f "/var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2"
qemu-img convert -p -O qcow2 -t unsafe -c -o compat=1.1 -o lazy_refcounts=on -o preallocation=off $IMGFILE  "/var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2"
rm -f $IMGFILE
set +x

if [ $ARCH = amd64 -o $ARCH = i386 ]; then
  EFI='--efi'
else
  EFI=''
fi

if [ $ARCH = ppc64 ]; then
  QEMU='-q qemu-system-ppc64 --qemu-options=-nodefaults'
else
  QEMU=''
fi

cat <<EOF
You may have to mannually install autopkgtest-virt-qemu at 
https://salsa.debian.org/ci-team/autopkgtest

After that, use
autopkgtest -u debci -B dpkg -- qemu $QEMU $EFI--dpkg-architecture=${ARCH} --timeout-reboot=300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
exit 0
