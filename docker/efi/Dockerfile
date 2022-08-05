FROM de.icr.io/erp_dev/ubuntu-focal:20220531

ENV KERNEL_VERSION=5.15.0-41-generic

SHELL ["/bin/bash", "-c"]

RUN apt-get update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y binutils \
    wget \
    overlayroot \
    isc-dhcp-client \
    sbsigntool \
    initramfs-tools \
    systemd-sysv \
    gnupg \
    linux-image-unsigned-${KERNEL_VERSION} \
    linux-modules-${KERNEL_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files for update-initramfs
COPY scripts/* /usr/share/initramfs-tools/scripts/
COPY hooks/* /usr/share/initramfs-tools/hooks/
COPY modules.d/* /usr/share/initramfs-tools/modules.d/

ARG SQUASHFS_IMAGE_HASH
ARG SQUASHFS_IMAGE_VERSION
ARG RELEASE_TYPE='production'

RUN sed -i "s|%SQUASHFS_HASH_PLACEHOLDER%|${SQUASHFS_IMAGE_HASH}|g" /usr/share/initramfs-tools/scripts/pxe
RUN sed -i "s|%SQUASHFS_IMAGE_VERSION%|${SQUASHFS_IMAGE_VERSION}|g" /usr/share/initramfs-tools/scripts/pxe
RUN sed -i "s|%RELEASE_TYPE%|${RELEASE_TYPE}|g" /usr/share/initramfs-tools/scripts/pxe

# Refactor
RUN chmod +x /usr/share/initramfs-tools/scripts/pxe
RUN chmod +x /usr/share/initramfs-tools/hooks/wget

RUN update-initramfs -c -k ${KERNEL_VERSION}

RUN echo "BOOT_IMAGE=/boot/vmlinuz boot=pxe maxTryCount=2 audit=1 audit_backlog_limit=8192 security=apparmor apparmor=1 ipv6.disable=1 oops=panic init_on_free=1" > cmdline.txt

RUN objcopy \
--add-section .cmdline=cmdline.txt --change-section-vma .cmdline=0x30000 \
--add-section .linux=/boot/vmlinuz-${KERNEL_VERSION} --change-section-vma .linux=0x40000 \
--add-section .initrd=/boot/initrd.img-${KERNEL_VERSION} --change-section-vma .initrd=0x3000000 \
/usr/lib/systemd/boot/efi/linuxx64.efi.stub pxe-boot.efi

# Certificates are read from Hashicorp Vault
COPY certs/* ./
RUN sbsign --output pxe-boot.efi.signed --key db.key --cert db.crt pxe-boot.efi
