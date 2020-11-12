# qemu-arm-image-builder
Shell scripts to build Linux images for QEMU ARM emulator

The scripts create an image file of Debian or Devuan Linux. Their releases, such as Buster, Bullseye, Beowulf, or Chimaera can be chosen. Target architectures are arm64, armhf, and armel. Host computer should run Debian, Devuan or Ubuntu. Host architecture can be anything. To use the scripts,

1. Download all the shell script.
2. Customize shell variables in `build-arm-debian-qemu-image.sh` or `build-arm-devuan-qemu-image.sh`.
3. Run the editted shell script.
4. At the end of shell script, it prints suitable command lines to start the built image by qemu.

To have a reasonable speed of emulation, KVM has to be enabled, if possible. The scripts print suitable command options to enable KVM. Note that Intel and AMD host CPU do not have ARM KVM. Recent ARM CPUs and Linux kernels have KVM capability. I tested the scripts on Debian Bullseye arm64 with Linux kernel 5.9 and qemu 5.1. It may be impossible to build an image of Debian stretch or older, and Devuan ASCII or older.

`console-setup` may [fail only at the first boot]( https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=973688). `virt-manager` is a friendly user interface to `qemu-system-aarch64` and `qemu-system-arm`. After installing it by `apt-get --install-recommends install virt-manager`, you may need to apply a patch at https://github.com/virt-manager/virt-manager/issues/174

# Secure bootable images for i386/amd64
By setting `ARCH=amd64` or `ARCH=i386` shell variable, the same scripts can produce secure-bootable QEMU images. As Debian [lacks i386 OVMF](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=842683) and [gives broken amd64 OVMF for secure boot](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=973783), I also include OVMF from Fedora 33. Working with OVMF files in Fedora 33 is much easier. QEMU should be started as `qemu-system-x86_64 -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on  -drive if=pflash,format=raw,unit=0,file=OVMF_CODE.secboot.fd,readonly=on  -drive if=pflash,format=raw,unit=1,file=copy_of_OVMF_VARS.secboot.fd`
