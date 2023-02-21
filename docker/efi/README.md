# The EFI bootloader

## Intro

This folder contains the files to build and sign the EFI bootloader.

## Dependencies

* The certs/ folder have to contain the signing certificate and key. Please see [more details](certs/README.md).
* Have access to de.icr.io/erp_dev/ubuntu-focal:20221130, or pull the ubuntu focal image and retag it to match the name
of the base image in the Dockerfile

## Folder structure
- [certs](certs/README.md)          - the signing certificate
- [gpg](gpg/README.md)              - gpg keys used
- [hooks](hooks/README.md)          - initramfs hooks
- [modules.d](modules.d/README.md)  - initramfs modules
- [scripts](scripts/README.md)      - initramfs scripts

## Build process (CI)

The EFI bootloader is build by Jenkins, using Docker. 
Signing keys are stored in Hashicorp Vault.
The final artifact contains the kernel, initramfs and the kernel command line file.
The binary is then signed and published to Nexus.

## Build process (manual)

The bootloader can be built independently of Jenkins, provided that the dependencies above are met.

The following arguments need to be provided to the docker build command:

- SQUASHFS_IMAGE_HASH - the sha512sum of the squashfs image, that will be checked in the pxe script, after download
- SQUASHFS_IMAGE_VERSION - the squasfs image version, to download from within the EFI bootloader 
- RELEASE_TYPE - production or debug

To build the EFI bootloader, see the docker build command in Jenkinsfile. 
After the docker image is build, the file pxe-boot.efi.signed can be copied with 'docker cp' from inside the image.
