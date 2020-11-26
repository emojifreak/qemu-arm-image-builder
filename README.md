**You are welcome to post a question to the github issue.** Built VM images are available at http://153.240.174.134:64193/autopkgtest-VM/

# qemu-arm-image-builder
Shell scripts to build Linux images for QEMU ARM emulator

The scripts create an image file of Debian or Devuan Linux. Their releases, such as Buster, Bullseye, Beowulf, or Chimaera can be chosen. Target architectures are arm64, armhf, and armel. Host computer should run Debian, Devuan or Ubuntu. Host architecture can be anything. To use the scripts,

1. Download all the shell script.
2. Customize shell variables in `build-arm-debian-qemu-image.sh` or `build-arm-devuan-qemu-image.sh`.
3. Run the editted shell script.
4. At the end of shell script, it prints suitable command lines to start the built image by qemu.

To have a reasonable speed of emulation, KVM has to be enabled, if possible. The scripts print suitable command options to enable KVM. Note that Intel and AMD host CPU do not have ARM KVM. Recent ARM CPUs and Linux kernels have KVM capability. I tested the scripts on Debian Bullseye arm64 with Linux kernel 5.9 and qemu 5.1. It may be impossible to build an image of Debian stretch or older, and Devuan ASCII or older.

`console-setup` may [fail only at the first boot]( https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=973688). `virt-manager` is a friendly user interface to `qemu-system-aarch64` and `qemu-system-arm`. After installing it by `apt-get --install-recommends install virt-manager`, you might need to apply a patch at https://github.com/virt-manager/virt-manager/issues/174

# Secure bootable images for i386/amd64
By setting `ARCH=amd64` or `ARCH=i386` shell variable, the same scripts can produce secure-bootable QEMU images. As Debian [lacks i386 OVMF](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=842683) and [gives amd64 OVMF inconvenient for autopkgtest-virt-qemu](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=973783), I also include OVMF from Fedora 33. QEMU can be started as `qemu-system-x86_64 -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on  -drive if=pflash,format=raw,unit=0,file=OVMF_CODE.secboot.fd,readonly=on  -drive if=pflash,format=raw,unit=1,file=copy_of_OVMF_VARS.secboot.fd`
When you want to build secure boot capable OVMF from the source, you can also use https://github.com/emojifreak/qemu-arm-image-builder/blob/main/OVMF-Fedora/my-ovmf-build.sh 

# ppc64el, ppc64 and powerpc (32-bit big endian) architectures
Experimental support is added. If you find any inconvenience, please report it as a github issue. So far I have seen no problem...

# build-gpt-autopkgtest-qemu-debian.sh
Builds a autopkgtest QEMU testbed for amd64, i386, arm64, armhf, armel, and ppc64el architectures.
The script also supports sysvinit-core as /sbin/init and btrfs root partition of the QEMU testbed.
Devuan testbed can also be made. I see build-gpt-autopkgtest-qemu-debian.sh as a temporary alternative
to autopkgtest-build-qemu until it includes support for armxx and ppc64el. Another QEMU bootable image
builder for Debian is available as [qemu-sbuild-utils](https://www.kvr.at/posts/qemu-sbuild-utils-01-sbuild-with-qemu/).
Autopkgtest-virt-qemu for arm and ppc VMs is posted at https://salsa.debian.org/ci-team/autopkgtest/-/merge_requests/97
To use an ARM testbed, you need to install `qemu-system-arm`, `qemu-efi-arm`, `qemu-efi-aarch64`, `ipxe-qemu`.
For a PowerPC, you need `qemu-system-ppc`. `MMVARIANT=apt` is OK for most packages, but it gives error to autopkgtest of systemd,
which is OK with `MMVARIANT=important`...

# s390x, mips64el, and mipsel
I do not know how to build a bootable image for s390x, mips64el, or mipsel. My impression is that there is no publicly available booting ROM for those architectures, similar to OVMF and AAVMF. **If you know how to do it, please tell me as a github issue here.**
