#!/bin/sh

MOUNTPT=/tmp/mnt$$
umount -qf ${LOOPDEV}p1
umount -qf ${LOOPDEV}p2
losetup -d ${LOOPDEV}
rm -f ${IMGFILE}
dd if=/dev/zero of=${IMGFILE} count=1 seek=`expr ${GIGABYTES} \* 1024 \* 2048 - 1`
losetup -P ${LOOPDEV} ${IMGFILE}
parted -- ${LOOPDEV} mklabel gpt mkpart ESP fat32 0% 100MiB mkpart ROOT ${ROOTFS} 100MiB -${SWAPGB}GiB set 1 esp on
if [ ${SWAPGB} -gt 0 ]; then
    parted -- ${LOOPDEV} mkpart SWAP linux-swap -${SWAPGB}GiB 100%
fi

while [ ! -b ${LOOPDEV}p2 ]; do
    partprobe ${LOOPDEV}
    sleep 1
done

mkfs.vfat -F 32 -n ESP ${LOOPDEV}p1
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
else
    KERNELPKG=linux-image-armmp-lpae:armhf
    GRUBPKG=grub-efi-arm
    GRUBTARGET=arm-efi
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
mmdebstrap --architectures=$MMARCH --variant=$MMVARIANT --components="main contrib non-free" --include=${KEYRINGPKG},${INITUDEVPKG},${KERNELPKG},${NETPKG},initramfs-tools,kmod,e2fsprogs,btrfs-progs,locales,tzdata,apt-utils,whiptail,debconf-i18n,keyboard-configuration,console-setup ${SUITE} ${MOUNTPT} ${MIRROR}

mkdir -p ${MOUNTPT}/boot/efi
mount -o async,discard,lazytime,noatime ${LOOPDEV}p1 ${MOUNTPT}/boot/efi

chroot ${MOUNTPT} dpkg-reconfigure locales
chroot ${MOUNTPT} dpkg-reconfigure tzdata
chroot ${MOUNTPT} dpkg-reconfigure keyboard-configuration
chroot ${MOUNTPT} passwd root
#chroot ${MOUNTPT} pam-auth-update
set +x

mount --bind /dev ${MOUNTPT}/dev
mount --bind /sys ${MOUNTPT}/sys
mount --bind /proc ${MOUNTPT}/proc

chroot ${MOUNTPT} apt-get -y update
chroot ${MOUNTPT} apt-get -y --no-install-recommends --no-show-progress install ${GRUBPKG}
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT="'"${KERNEL_CMDLINE}"\"/ ${MOUNTPT}/etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT='"${GRUB_TIMEOUT}"/ ${MOUNTPT}/etc/default/grub
#cat ${MOUNTPT}/etc/default/grub
chroot ${MOUNTPT} grub-mkconfig -o /boot/grub/grub.cfg
# --force-extra-removable is necessary below!
chroot ${MOUNTPT} grub-install --target=${GRUBTARGET} --force-extra-removable --no-nvram --no-floppy --modules="part_msdos part_gpt" --grub-mkdevicemap=/boot/grub/device.map ${LOOPDEV}

umount -f ${MOUNTPT}/dev
umount -f ${MOUNTPT}/sys
umount -f ${MOUNTPT}/proc

cp /etc/resolv.conf /etc/environment ${MOUNTPT}/etc
echo ${YOURHOSTNAME} >${MOUNTPT}/etc/hostname
if [ ${ROOTFS} = btrfs ]; then
   cat >${MOUNTPT}/etc/fstab <<EOF
LABEL=ROOT / ${ROOTFS} rw,ssd,async,lazytime,discard,strictatime,autodefrag,nobarrier,commit=3600,compress-force=lzo 0 1
LABEL=ESP /boot/efi vfat rw,async,lazytime,discard 0 2
EOF
elif [ ${ROOTFS} = btrfs ]; then
   cat >${MOUNTPT}/etc/fstab <<EOF
LABEL=ROOT / ${ROOTFS} rw,async,lazytime,discard,strictatime,nobarrier,commit=3600,data=writeback 0 1
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
  chroot ${MOUNTPT} apt-get -y --purge --autoremove purge python2.7-minimal
fi
if [ $NETWORK = network-manager -a $NETWORK = systemd-networkd ]; then
  chroot ${MOUNTPT} apt-get -y --purge --autoremove purge ifupdown
  rm -f ${MOUNTPT}/etc/network/interfaces
fi  
set +x

cat >>${MOUNTPT}/root/.profile <<EOF
echo "$NETCONFIG"
EOF

if [ -w ${MOUNTPT}/etc/inittab ]; then
    echo 'C0:2345:respawn:/sbin/getty -8 --noclear --keep-baud console 115200,38400,9600' >>${MOUNTPT}/etc/inittab
fi

umount -f ${MOUNTPT}/boot/efi
umount -f ${MOUNTPT}
rm -rf ${MOUNTPT}
losetup -d ${LOOPDEV}

# Identify the command for starting the guest

if [ $ARCH = arm64 ]; then
    OVMFCODE=/usr/share/AAVMF/AAVMF_CODE.fd
    OVMFDATA=/usr/share/AAVMF/AAVMF_VARS.fd
else
    OVMFCODE=/usr/share/AAVMF/AAVMF32_CODE.fd
    OVMFDATA=/usr/share/AAVMF/AAVMF32_VARS.fd
fi

HOSTARCH=`dpkg --print-architecture`
if [ $HOSTARCH = arm64 ]; then
    QEMU=qemu-system-aarch64
    KVM='-enable-kvm'
    if [ $ARCH = arm64 ]; then
	CPU=host
    else
	CPU=host,aarch64=off
    fi
elif [ $HOSTARCH = armhf ]; then
    if [ $ARCH = arm64 ]; then
	QEMU=qemu-system-aarch64
	CPU=max
	KVM=
    else
	QEMU=qemu-system-arm
	CPU=host
	if [ -e /dev/kvm ]; then
	    KVM=-enable-kvm
	else
	    KVM=
	fi
    fi
elif [ $HOSTARCH = armel ]; then
    if [ $ARCH = arm64 ]; then
	QEMU=qemu-system-aarch64
	CPU=max
	KVM=
    elif [ $ARCH = armhf ]; then
	QEMU=qemu-system-arm
	CPU=max
	KVM=
    else
	QEMU=qemu-system-arm
	CPU=host
	KVM=
    fi
else
    KVM=
    CPU=max
    if [ $ARCH = arm64 ]; then
	QEMU=qemu-system-aarch64
    else
	QEMU=qemu-system-arm
    fi
fi

cat <<EOF


To start the guest run the following commands:
cp $OVMFDATA /tmp/efivars.fd
$QEMU -machine virt -nographic -net nic,model=virtio -net user -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0,id=rng-device0 -drive file=${IMGFILE},if=virtio,index=0,format=raw -drive if=pflash,format=raw,read-only,file=${OVMFCODE} -drive if=pflash,format=raw,file=/tmp/efivars.fd -m 1024 -cpu $CPU $KVM
EOF

exit 0
