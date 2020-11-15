#!/bin/sh

TARGET_BIT=64 # 64 or 32
YOUR_OPT="-DTPM_ENABLE=FALSE -DTPM_CONFIG_ENABLE=FALSE -DNETWORK_TLS_ENABLE=FALSE -DNETWORK_IP6_ENABLE=FALSE -DNETWORK_HTTP_BOOT_ENABLE=FALSE -DNETWORK_ALLOW_HTTP_CONNECTIONS=FALSE -DLOAD_X64_ON_IA32_ENABLE=TRUE"

DEBIAN_KEY="4e32566d-8e9e-4f52-81d3-5bb9715f9727:MIIDvTCCAqWgAwIBAgIURQHuOT5SKXg234VCyOV7u4jRSzcwDQYJKoZIhvcNAQELBQAwbjEPMA0GA1UECgwGRGViaWFuMS0wKwYDVQQDDCREZWJpYW4gVUVGSSBTZWN1cmUgQm9vdCAoUEsvS0VLIGtleSkxLDAqBgkqhkiG9w0BCQEWHWRlYmlhbi1kZXZlbEBsaXN0cy5kZWJpYW4ub3JnMB4XDTE5MDcwODIzNDI0OVoXDTI5MDcwNTIzNDI0OVowbjEPMA0GA1UECgwGRGViaWFuMS0wKwYDVQQDDCREZWJpYW4gVUVGSSBTZWN1cmUgQm9vdCAoUEsvS0VLIGtleSkxLDAqBgkqhkiG9w0BCQEWHWRlYmlhbi1kZXZlbEBsaXN0cy5kZWJpYW4ub3JnMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAm6tJi7ql+lQqcZp5BcQbRhHFs71ZYoBxrbtsxFColtaJ6+gR1Ig8SeSPUc2lh8PS/lEeOhu/2Fs4U7WdaFLRPoLL2/1eAYEwxL5z4NZWP0oo8TPXUmF7hKJAohiIeFsU0B5tariuEESvEpmmey3puo0KWJM4aett8G+XIv7gD7Sk+cgrO3O5Uc8fH+VmB8vd907zVypJaVNBgPzVanXZug1nvVPGHdXlZb8LjfwWWGXtWaZXjzNIpmwn3LQdnpSeY4sZAr/gAVI0KKQTiP75ewYd4neFB55OG6rKDGrk3yvpiqxCBd4y1TT54m+WwtQFX8kg2DOaAYJdlGl4Ti7gxwIDAQABo1MwUTAdBgNVHQ4EFgQUiAnrn/p9LV3bMGenr7mJjqPuAnMwHwYDVR0jBBgwFoAUiAnrn/p9LV3bMGenr7mJjqPuAnMwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEACnQviYBeHsTyyaJNtjTusWid8r13heVoZtX/diApnw3zzRufIk4mnREZk5ajmwz9iN+g7xEJHsJwbyD2/r7DWjxAR3mgLILGQjzEPK9Vf4rDDQxqz598nby1bTNzzfkTDo5Nzvj2VHTHkCjrb1gx1kGeJacEQIoo2zY5c+rknow+Qlp7BSB45k1pH7q/obcC2eOr/ELZd83g3Qg7vpZ5XF1x7sdo6KYIaS3/mK1RyxvvObBScAPTPKfOpfCTYsprYUvce8cAnoA6v6+Veff2FH5F8bRsyDGfCjgn/Dz7RCJOetNyFy92XMYAiyYFFZXrcVJfW5DIy/1TAaT/CsitJQ=="
UBUNTU_KEY="4e32566d-8e9e-4f52-81d3-5bb9715f9727:MIIDNjCCAh4CCQCUy69JzVan2DANBgkqhkiG9w0BAQsFADBdMS0wKwYDVQQDDCRVYnVudHUgT1ZNRiBTZWN1cmUgQm9vdCAoUEsvS0VLIGtleSkxLDAqBgkqhkiG9w0BCQEWHXVidW50dS1kZXZlbEBsaXN0cy51YnVudHUuY29tMB4XDTE4MDYyMDIxNDg0NloXDTI4MDYxNzIxNDg0NlowXTEtMCsGA1UEAwwkVWJ1bnR1IE9WTUYgU2VjdXJlIEJvb3QgKFBLL0tFSyBrZXkpMSwwKgYJKoZIhvcNAQkBFh11YnVudHUtZGV2ZWxAbGlzdHMudWJ1bnR1LmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMuwK+l3nl5x6ebrHYVShs/7jPAKeTTMu4MQlTbNoOZvVQhOcedjkBNaPPdd63TBxYFAnJhUBLl9hW/GB5Fn9itT0yh5G64XCBafy3rJLF8L99VDUYEuvB+a3boYATCToVnODb8h0ImORBF8sgKZm65CJlgQ93YGZbjLePnuawhU2EVH2HFyLZEWjd3JPxstlzGj+JiwvETdFX/fHbnrW+fLCLEnLLZ/YPo6We0mtVTEqHWm6G5WUIbpzPzOOGpiCKHdI+VFsX7w1TBdMhCqnxcpLn7NRXEEgw+OQ5gnOLR9kTKI+MRkux9pDGZ5v9VMcPZi2iZTHRd9briIGOL/fo0CAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAGLAtUs7fnf5oKU7E7+woUrHP03WXAwhTNI9eTs7YLPgwC2qGAGkzdUZUbzc4zS4SaItITlYYeWfZ9PvPhPGyIZOeuBMoUeBknsC2daRVX11aAcgOnQhxMD0WjSRG5nQ5rXRZ/NwYvctJR81l41kDToNqjBIjJ3FThzz8hHyMv/DCh3ch/X2Hj7ib+1IPfoHFk+mD/6e+y46wHWS5u0Bol9w4VBMwa3FYniFgKrAmnoiuo2br5fBbgH/7326lJ7Qb/H4mBLKz/c3iw4PF+KQxspc04tJdvQ+pDEtTUiXVE0zcBip2EJgPVK0szO5H6gtXbfyoTqDr1DKaD4x9JD3yKQ=="
FEDORA_KEY="4e32566d-8e9e-4f52-81d3-5bb9715f9727:MIIDoDCCAoigAwIBAgIJAP71iOjzlsDxMA0GCSqGSIb3DQEBCwUAMFExKzApBgNVBAMTIlJlZCBIYXQgU2VjdXJlIEJvb3QgKFBLL0tFSyBrZXkgMSkxIjAgBgkqhkiG9w0BCQEWE3NlY2FsZXJ0QHJlZGhhdC5jb20wHhcNMTQxMDMxMTExNTM3WhcNMzcxMDI1MTExNTM3WjBRMSswKQYDVQQDEyJSZWQgSGF0IFNlY3VyZSBCb290IChQSy9LRUsga2V5IDEpMSIwIAYJKoZIhvcNAQkBFhNzZWNhbGVydEByZWRoYXQuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkB+Ee42865cmgm2Iq4rJjGhw+d9LB7I3gwsCyGdoMJ7j8PCZSrhZV8ZB9jiL/mZMSek3N5IumAEeWxRQ5qiNJQ31huarMMtAFuqNixaGcEM38s7Akd9xFI6ZDom2TG0kHozkL08l0LoG+MboGRh2cx2BbajYBc86yHsoyDajFg0pjJmaaNyrwE2Nv1q7K6k5SwSXHPk2u8U6hgSur9SCe+Cr3kkFaPz2rmgabJBNVxk8ZGYD9sdSm/eUz5NqoWjJqs+Za7yqXgjnORz3+A+6Bn7xy+h23f4i2q06Xls06rPJ4E0EKX64YLkF77XZF1hWFmC5MDLwNkrD8nmNEkBw8wIDAQABo3sweTAJBgNVHRMEAjAAMCwGCWCGSAGG+EIBDQQfFh1PcGVuU1NMIEdlbmVyYXRlZCBDZXJ0aWZpY2F0ZTAdBgNVHQ4EFgQUPOlg4/8ZoQp7o0L0jUIutNWccuwwHwYDVR0jBBgwFoAUPOlg4/8ZoQp7o0L0jUIutNWccuwwDQYJKoZIhvcNAQELBQADggEBAFxNkoi0gl8drYsR7N8GpnqlK583VQyNbgUArbcMQYlpz9ZlBptReNKtx7+c3AVzf+ceORO06rYwfUB1q5xDC9+wwhu/MOD0/sDbYiGY9sWv3jtPSQrmHvmGsD8N1tRGN9tUdF7/EcJgxnBYxRxv7LLYbm/DvDOHOKTzRGScNDsolCZ4J58WF+g7aQolqXM2fp43XOzoP9uR+RKzPc7n3RXDrowFIGGbld6br/qxXBzll+fDNBGF9YonJqRwNuwM9oM9kPc28/nzFdSQYr5TtK/TSa/v9HPoe3bkRCo3uoGkmQw6MSRxoOTktxrLR+SqIs/vdWGA40O3SFdzET14m2k="

if [ $TARGET_BIT -eq 64 ]; then
    ARCH_OPT="-a X64 -a IA32 -DEXCLUDE_SHELL_FROM_FD"
    DIR=Ovmf3264
    UEFIISO=UefiShell.fedora-amd64.iso
    QEMU=qemu-system-x86_64
elif [ $TARGET_BIT -eq 32 ]; then
    ARCH_OPT="-a IA32"
    DIR=OvmfIa32
    UEFIISO=UefiShell.fedora-i386.iso
    QEMU=qemu-system-x86_64
else
    echo "Unknown Target Bits"
    exit 1
fi

if [ ! -e edk2 ]; then
    git clone --recursive https://github.com/tianocore/edk2.git
    # The following patch is from  https://src.fedoraproject.org/rpms/edk2/raw/master/f/0011-OvmfPkg-allow-exclusion-of-the-shell-from-the-firmwa.patch
    cd edk2/OvmfPkg
    patch -l --binary <<'EOF'
--- edk2/OvmfPkg/OvmfPkgIa32.fdf-org	2020-11-15 21:26:53.664927082 +0900
+++ edk2/OvmfPkg/OvmfPkgIa32.fdf	2020-11-15 21:28:25.845927726 +0900
@@ -291,12 +291,14 @@
 INF  FatPkg/EnhancedFatDxe/Fat.inf
 INF  MdeModulePkg/Universal/Disk/UdfDxe/UdfDxe.inf
 
+!ifndef $(EXCLUDE_SHELL_FROM_FD)
 !if $(TOOL_CHAIN_TAG) != "XCODE5"
 INF  ShellPkg/DynamicCommand/TftpDynamicCommand/TftpDynamicCommand.inf
 INF  ShellPkg/DynamicCommand/HttpDynamicCommand/HttpDynamicCommand.inf
 INF  OvmfPkg/LinuxInitrdDynamicShellCommand/LinuxInitrdDynamicShellCommand.inf
 !endif
 INF  ShellPkg/Application/Shell/Shell.inf
+!endif
 
 INF MdeModulePkg/Logo/LogoDxe.inf
 
--- edk2/OvmfPkg/OvmfPkgIa32X64.fdf-org	2020-11-15 21:27:10.724383199 +0900
+++ edk2/OvmfPkg/OvmfPkgIa32X64.fdf	2020-11-15 21:31:41.843134446 +0900
@@ -292,12 +292,14 @@
 INF  FatPkg/EnhancedFatDxe/Fat.inf
 INF  MdeModulePkg/Universal/Disk/UdfDxe/UdfDxe.inf
 
+!ifndef $(EXCLUDE_SHELL_FROM_FD)
 !if $(TOOL_CHAIN_TAG) != "XCODE5"
 INF  ShellPkg/DynamicCommand/TftpDynamicCommand/TftpDynamicCommand.inf
 INF  ShellPkg/DynamicCommand/HttpDynamicCommand/HttpDynamicCommand.inf
 INF  OvmfPkg/LinuxInitrdDynamicShellCommand/LinuxInitrdDynamicShellCommand.inf
 !endif
 INF  ShellPkg/Application/Shell/Shell.inf
+!endif
 
 INF MdeModulePkg/Logo/LogoDxe.inf
 
--- edk2/OvmfPkg/OvmfPkgX64.fdf-org	2020-11-15 21:27:20.428071469 +0900
+++ edk2/OvmfPkg/OvmfPkgX64.fdf	2020-11-15 21:31:13.380150537 +0900
@@ -301,12 +301,14 @@
 INF  FatPkg/EnhancedFatDxe/Fat.inf
 INF  MdeModulePkg/Universal/Disk/UdfDxe/UdfDxe.inf
 
+!ifndef $(EXCLUDE_SHELL_FROM_FD)
 !if $(TOOL_CHAIN_TAG) != "XCODE5"
 INF  ShellPkg/DynamicCommand/TftpDynamicCommand/TftpDynamicCommand.inf
 INF  ShellPkg/DynamicCommand/HttpDynamicCommand/HttpDynamicCommand.inf
 INF  OvmfPkg/LinuxInitrdDynamicShellCommand/LinuxInitrdDynamicShellCommand.inf
 !endif
 INF  ShellPkg/Application/Shell/Shell.inf
+!endif
 
 INF MdeModulePkg/Logo/LogoDxe.inf
 
EOF
    cd ../..
    chmod -R a-w edk2
fi
if [ ! -e qemu-ovmf-secureboot ]; then
    git clone --recursive https://github.com/rhuefi/qemu-ovmf-secureboot.git
    chmod -R a-w qemu-ovmf-secureboot
fi

for iso in UefiShell.fedora-i386.iso UefiShell.fedora-amd64.iso; do
    if [ ! -e $iso ]; then
	wget https://github.com/emojifreak/qemu-arm-image-builder/raw/main/OVMF-Fedora/$iso
    fi
done


rm -rf edk2-$TARGET_BIT
cp -Rp edk2 edk2-$TARGET_BIT
chmod -R u+w edk2-$TARGET_BIT
cd edk2-$TARGET_BIT
./OvmfPkg/build.sh -DFD_SIZE_4MB -DSECURE_BOOT_ENABLE=TRUE -DSMM_REQUIRE=TRUE $ARCH_OPT $YOUR_OPT
cd ..

rm -f edk2-$TARGET_BIT/Build/${DIR}/DEBUG_GCC5/FV/OVMF_VARS.secboot.fd
python3 qemu-ovmf-secureboot/ovmf-vars-generator --qemu-binary $QEMU --verbose --verbose --enable-kvm --ovmf-binary edk2-$TARGET_BIT/Build/${DIR}/DEBUG_GCC5/FV/OVMF_CODE.fd --ovmf-template-vars edk2-$TARGET_BIT/Build/${DIR}/DEBUG_GCC5/FV/OVMF_VARS.fd --uefi-shell-iso $UEFIISO --skip-testing --oem-string "$FEDORA_KEY" --oem-string "$DEBIAN_KEY" --oem-string "$UBUNTU_KEY" edk2-$TARGET_BIT/Build/${DIR}/DEBUG_GCC5/FV/OVMF_VARS.secboot.fd


cat <<EOF

Use
edk2-$TARGET_BIT/Build/${DIR}/DEBUG_GCC5/FV/OVMF_CODE.fd
edk2-$TARGET_BIT/Build/${DIR}/DEBUG_GCC5/FV/OVMF_VARS.secboot.fd
as
qemu-system-x86_64 -enable-kvm -cpu max -machine q35,smm=on,accel=kvm -global driver=cfi.pflash01,property=secure,value=on -drive if=pflash,unit=0,format=raw,read-only=on,file=OVMF_CODE.fd -drive if=pflash,unit=1,format=raw,file=OVMF_VARS.secboot.fd 
EOF
