#!/bin/sh

if [ ${ROOTFS} = btrfs ]; then
  if [ $ARCH = ppc64 -o $ARCH = ppc64el ]; then
    echo "Due to the different page size 65536 of 64-bit PowerPC, ROOTFS is changed to ext4"
    unset ROOTFS
    ROOTFS=ext4
  fi
fi

umount -qf ${LOOPDEV}p1
umount -qf ${LOOPDEV}p2
losetup -d ${LOOPDEV}
rm -f ${IMGFILE}
#dd if=/dev/zero of=${IMGFILE} count=1 seek=`expr ${GIGABYTES} \* 1024 \* 2048`
qemu-img create -f raw -o preallocation=off -o nocow=off ${IMGFILE} ${GIGABYTES}G
losetup -P ${LOOPDEV} ${IMGFILE}
ESP=esp
BOOTSIZE=100MiB
if [ $ARCH = ppc64 -o $ARCH = ppc64el -o $ARCH = powerpc ]; then
  BOOTSIZE=9MiB
  ESP=prep
fi
if [ "$SWAPGB" -gt 0 ]; then
  parted -- ${LOOPDEV} mklabel gpt mkpart ESP fat32 0% $BOOTSIZE mkpart ROOT ${ROOTFS} $BOOTSIZE -${SWAPGB}GiB set 1 $ESP on
else 
  parted -- ${LOOPDEV} mklabel gpt mkpart ESP fat32 0% $BOOTSIZE mkpart ROOT ${ROOTFS} $BOOTSIZE '100%' set 1 $ESP on
fi

if [ ${SWAPGB} -gt 0 ]; then
    parted -- ${LOOPDEV} mkpart SWAP linux-swap -${SWAPGB}GiB 100%
fi

while [ ! -b ${LOOPDEV}p2 ]; do
    partprobe ${LOOPDEV}
    sleep 1
done

if [ $ARCH != ppc64el -a $ARCH != ppc64 -a $ARCH != powerpc ]; then
  mkfs.vfat -F 32 -n ESP ${LOOPDEV}p1
else
  dd bs=65536 if=/dev/zero of=${LOOPDEV}p1
fi

eval mkfs.${ROOTFS} -L ROOT ${LOOPDEV}p2
if [ ${SWAPGB} -gt 0 ]; then
    mkswap -L SWAP ${LOOPDEV}p3
fi

mkdir -p ${MOUNTPT}
if [ ${ROOTFS} = btrfs ]; then
    mount -t ${ROOTFS} -o  ssd,async,lazytime,discard,noatime,autodefrag,nobarrier,commit=3600,compress-force=lzo ${LOOPDEV}p2 ${MOUNTPT}
elif [ ${ROOTFS} = ext4 ]; then
    mount -t ${ROOTFS} -o async,lazytime,discard,noatime,nobarrier,commit=3600,delalloc,noauto_da_alloc,data=writeback ${LOOPDEV}p2 ${MOUNTPT}
else
    echo "Unsupported filesystem type ${ROOTFS}"
    exit 1
fi

if [ "${ARCH}" = arm64 ]; then
    KERNELPKG=linux-image-arm64
    GRUBPKG=grub-efi-arm64
    GRUBTARGET=arm64-efi
elif [ "${ARCH}" = armhf -o  "${ARCH}" = armel ]; then
    KERNELPKG=linux-image-armmp-lpae:armhf
    GRUBPKG=grub-efi-arm
    GRUBTARGET=arm-efi
elif [ "${ARCH}" = amd64 ]; then
    KERNELPKG=linux-image-amd64
    GRUBPKG=grub-efi-amd64
    GRUBTARGET=x86_64-efi
elif [ "${ARCH}" = i386 ]; then
    KERNELPKG=linux-image-686-pae
    GRUBPKG=grub-efi-ia32
    GRUBTARGET=i386-efi
elif [ "${ARCH}" = ppc64el ]; then
    KERNELPKG=linux-image-powerpc64le
    GRUBPKG=grub-ieee1275
    GRUBTARGET=powerpc-ieee1275
elif [ "${ARCH}" = ppc64 ]; then
    KERNELPKG=linux-image-powerpc64
    GRUBPKG=grub-ieee1275
    GRUBTARGET=powerpc-ieee1275
    apt-get -q -y install debian-ports-archive-keyring
    KEYRINGPKG=debian-ports-archive-keyring,$KEYRINGPKG
    MIRROR=-
    MMCOMPONENTS=main
elif [ "${ARCH}" = powerpc ]; then
    KERNELPKG=linux-image-powerpc-smp
    GRUBPKG=grub-ieee1275
    GRUBTARGET=powerpc-ieee1275
    apt-get -q -y install debian-ports-archive-keyring
    KEYRINGPKG=debian-ports-archive-keyring,$KEYRINGPKG
    MIRROR=-
    MMCOMPONENTS=main
#elif [ "${ARCH}" = sparc64 ]; then
#    KERNELPKG=linux-image-sparc64
#    GRUBPKG=grub-ieee1275
#    GRUBTARGET=sparc64-ieee1275
else
  echo "Unknown supported architecture ${ARCH} !"
  exit 1
fi

if [ -z "$MMCOMPONENTS" ]; then
  MMCOMPONENTS="main contrib non-free"
fi

if [ ${ARCH} = armel ]; then
    MMARCH=armel,armhf
else
    MMARCH=${ARCH}
fi

if [ $NETWORK = ifupdown ]; then
    NETPKG=ifupdown,isc-dhcp-client
elif [ $NETWORK = network-manager ]; then
    NETPKG=network-manager
elif [ $NETWORK = systemd-networkd ]; then
    NETPKG=systemd
else
    NETPKG=iproute2
fi

set -x
if [ $ARCH != ppc64 -a $ARCH != powerpc ]; then
  mmdebstrap --architectures=$MMARCH --variant=$MMVARIANT --components="$MMCOMPONENTS" --include=${KEYRINGPKG},${INITUDEVPKG},${KERNELPKG},${NETPKG},initramfs-tools,kmod,e2fsprogs,btrfs-progs,locales,tzdata,apt-utils,whiptail,debconf-i18n,keyboard-configuration,console-setup ${SUITE} ${MOUNTPT} ${MIRROR}
else
  mmdebstrap --architectures=$MMARCH --variant=$MMVARIANT --components="$MMCOMPONENTS" --include=${KEYRINGPKG},${INITUDEVPKG},${KERNELPKG},${NETPKG},initramfs-tools,kmod,e2fsprogs,btrfs-progs,locales,tzdata,apt-utils,whiptail,debconf-i18n,keyboard-configuration,console-setup ${SUITE} ${MOUNTPT} ${MIRROR} <<EOF
deb http://deb.debian.org/debian-ports sid main
deb http://deb.debian.org/debian-ports unreleased main
EOF
fi

if [ $ARCH != ppc64el -a $ARCH != ppc64 -a $ARCH != powerpc ]; then
  mkdir -p ${MOUNTPT}/boot/efi
  mount -o async,discard,lazytime,noatime ${LOOPDEV}p1 ${MOUNTPT}/boot/efi
fi


chroot ${MOUNTPT} dpkg-reconfigure locales
chroot ${MOUNTPT} dpkg-reconfigure tzdata
chroot ${MOUNTPT} dpkg-reconfigure keyboard-configuration
chroot ${MOUNTPT} passwd root
#chroot ${MOUNTPT} pam-auth-update
set +x

#touch ${MOUNTPT}${LOOPDEV}
#mount --bind ${LOOPDEV} ${MOUNTPT}${LOOPDEV}
mount --bind /dev ${MOUNTPT}/dev
mount --bind /dev/pts ${MOUNTPT}/dev/pts
mount --bind /sys ${MOUNTPT}/sys
mount --bind /proc ${MOUNTPT}/proc

chroot ${MOUNTPT} apt-get -qq update
chroot ${MOUNTPT} apt-get -qq -y --install-recommends --no-show-progress install ${GRUBPKG}
chroot ${MOUNTPT} apt-get -qq -y --autoremove --no-show-progress purge os-prober
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT="'"${KERNEL_CMDLINE}"\"/ ${MOUNTPT}/etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT='"${GRUB_TIMEOUT}"/ ${MOUNTPT}/etc/default/grub
#cat ${MOUNTPT}/etc/default/grub
chroot ${MOUNTPT} grub-mkconfig -o /boot/grub/grub.cfg
# --force-extra-removable is necessary below!
if [ $ARCH != ppc64el -a $ARCH != ppc64 -a $ARCH != powerpc ]; then
  chroot ${MOUNTPT} grub-install --target=${GRUBTARGET} --force-extra-removable --no-nvram --no-floppy --modules="part_msdos part_gpt" --grub-mkdevicemap=/boot/grub/device.map ${LOOPDEV}
else
  chroot ${MOUNTPT} grub-install --target=${GRUBTARGET} --no-nvram --no-floppy --modules="part_msdos part_gpt" --grub-mkdevicemap=/boot/grub/device.map ${LOOPDEV}p1
fi

umount -f ${MOUNTPT}/dev/pts
umount -f ${MOUNTPT}/dev
#umount -f ${MOUNTPT}${LOOPDEV}
#rm -f ${MOUNTPT}${LOOPDEV}
umount -f ${MOUNTPT}/sys
umount -f ${MOUNTPT}/proc

echo ${YOURHOSTNAME} >${MOUNTPT}/etc/hostname
if [ ${ROOTFS} = btrfs ]; then
   cat >${MOUNTPT}/etc/fstab <<EOF
LABEL=ROOT / ${ROOTFS} rw,ssd,async,lazytime,discard,strictatime,autodefrag,nobarrier,commit=3600,compress-force=lzo 0 1
EOF
elif [ ${ROOTFS} = ext4 ]; then
   cat >${MOUNTPT}/etc/fstab <<EOF
LABEL=ROOT / ${ROOTFS} rw,async,lazytime,discard,strictatime,nobarrier,commit=3600 0 1
EOF
else
    echo "Unsupported filesystem $ROOTFS"
    exit 0
fi

if [ $ARCH != ppc64el -a $ARCH != ppc64 -a $ARCH != powerpc ]; then
   cat >>${MOUNTPT}/etc/fstab <<EOF
LABEL=ESP /boot/efi vfat rw,async,lazytime,discard 0 2
EOF
fi

if [ "$SWAPGB" -gt 0 ]; then
  echo 'LABEL=SWAP none swap sw,discard 0 0' >>${MOUNTPT}/etc/fstab
fi

if [ $NETWORK != none ]; then 
  echo "IPv4 DHCP is assumed."
  NETIF=eth0

  if [ $NETWORK = ifupdown ]; then
    NETCONFIG="Network configurations can be changed by /etc/network/interfaces"
    cat >>${MOUNTPT}/etc/network/interfaces <<EOF
auto $NETIF
iface $NETIF inet dhcp
EOF
    echo "/etc/network/interfaces is"
    cat ${MOUNTPT}/etc/network/interfaces
  elif [ $NETWORK = network-manager ]; then
    NETCONFIG="Network configurations can be changed by nmtui"
  elif [ $NETWORK = systemd-networkd ]; then
    NETCONFIG="Network configurations can be changed by /etc/systemd/network/${NETIF}.network"
    cat >${MOUNTPT}/etc/systemd/network/${NETIF}.network <<EOF
[Match]
Name=${NETIF}

[Network]
DHCP=yes
EOF
    chroot ${MOUNTPT} systemctl enable systemd-networkd
  fi
fi

set -x
if [ "$SUITE" != buster -a "$SUITE" != beowulf ]; then
  chroot ${MOUNTPT} apt-get -qq -y --purge --autoremove purge python2.7-minimal
fi
if [ $NETWORK = network-manager -o $NETWORK = systemd-networkd ]; then
  chroot ${MOUNTPT} apt-get -qq -y --purge --autoremove purge ifupdown
  rm -f ${MOUNTPT}/etc/network/interfaces
fi  
set +x

