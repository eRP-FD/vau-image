FROM de.icr.io/erp_dev/ubuntu-focal:20210416

ENV BASE_KERNEL_VERSION=5.11.16
ENV KERNEL_RELEASE_VERSION=5.11.16-051116-generic_5.11.16-051116.202104211235
ENV KERNEL_VERSION=5.11.16-051116-generic


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
    && rm -rf /var/lib/apt/lists/*

COPY gpg/ /tmp/gpg/

# Downloads debian packages for the Linux kernel and verifies that the same number could be verified via sha256sum from a signed checksum file
RUN gpg --import /tmp/gpg/*.gpg && \
    wget -q https://kernel.ubuntu.com/~kernel-ppa/mainline/v${BASE_KERNEL_VERSION}/amd64/linux-image-unsigned-${KERNEL_RELEASE_VERSION}_amd64.deb && \
    wget -q https://kernel.ubuntu.com/~kernel-ppa/mainline/v${BASE_KERNEL_VERSION}/amd64/linux-modules-${KERNEL_RELEASE_VERSION}_amd64.deb && \
    ls linux-*.deb > /tmp/linux-downloaded && \
    wget -q https://kernel.ubuntu.com/~kernel-ppa/mainline/v${BASE_KERNEL_VERSION}/amd64/CHECKSUMS && \
    wget -q https://kernel.ubuntu.com/~kernel-ppa/mainline/v${BASE_KERNEL_VERSION}/amd64/CHECKSUMS.gpg && \
    gpg --quiet --verify CHECKSUMS.gpg CHECKSUMS && \
    sha256sum --ignore-missing --check CHECKSUMS | sed -n 's/^\(linux-.*\.deb\): OK$/\1/p' | sort | tee /tmp/linux-verified && \
    diff --report-identical-files /tmp/linux-*

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

# update-initramfs
RUN dpkg -i $(cat /tmp/linux-verified) && \
    rm -f linux-*.deb

RUN echo "BOOT_IMAGE=/boot/vmlinuz boot=pxe maxTryCount=2 audit=1 audit_backlog_limit=8192 security=apparmor apparmor=1 ipv6.disable=1 oops=panic init_on_free=1" > cmdline.txt

RUN objcopy \
--add-section .cmdline=cmdline.txt --change-section-vma .cmdline=0x30000 \
--add-section .linux=/boot/vmlinuz-${KERNEL_VERSION} --change-section-vma .linux=0x40000 \
--add-section .initrd=/boot/initrd.img-${KERNEL_VERSION} --change-section-vma .initrd=0x3000000 \
/usr/lib/systemd/boot/efi/linuxx64.efi.stub pxe-boot.efi

# Certificates are read from Hashicorp Vault
COPY certs/* ./
RUN sbsign --output pxe-boot.efi.signed --key db.key --cert db.crt pxe-boot.efi
