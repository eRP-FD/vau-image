FROM de.icr.io/erp_dev/ubuntu-noble:20261110

ENV KERNEL_VERSION=6.8.0-149-generic

SHELL ["/bin/bash", "-c"]

RUN apt-get update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    overlayroot \
    sbsigntool \
    initramfs-tools \
    systemd-sysv \
    systemd-boot-efi \
    systemd-ukify \
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

# Certificates are read from Hashicorp Vault
COPY certs/* ./

RUN ukify build \
    --stub=/usr/lib/systemd/boot/efi/linuxx64.efi.stub \
    --linux=/boot/vmlinuz-${KERNEL_VERSION} \
    --initrd=/boot/initrd.img-${KERNEL_VERSION} \
    --cmdline='BOOT_IMAGE=/boot/vmlinuz boot=pxe maxTryCount=2 audit=1 audit_backlog_limit=8192 security=apparmor apparmor=1 ipv6.disable=1 oops=panic init_on_free=1' \
    --uname=${KERNEL_VERSION} \
    --secureboot-private-key=db.key \
    --secureboot-certificate=db.crt \
    --output=pxe-boot.efi.signed

