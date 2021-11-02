# Intro

This project is the build pipeline for the VAU image with erp-processing-context. 
The artifacts are a signed "all-in-one" efi bootloader and a squasfs file. These are stored in Nexus.

## eRp Processing Context Version

The eRp Processing Context Version can be changed in build.gradle, by changing the **eRpPCVersion** variable value.
The archive with that version will be pulled from Nexus, and unarchived in vau/erp to be copied inside Dockerfiles.  

## Dockerfiles

### Bootloader (docker/efi)
The image has the tools to build the efi bootloader.
The most relevant part is the scripts/pxe script, which downloades the squashfs image form nexus, and checksums it.

Please [visit for more details](docker/efi/README.md)

### VAU image (docker/vau)
The main filesystem for the bootable image.
The structure under files folder is meant to emulate the root "/" of the server
The hostname and nameservers are provided via DHCP.

Please [visit for more details](docker/vau/README.md)

### Build image (docker/build)
The image has tools used to create the squashfs, and is used as a Jenkins agent.
Please [visit for more details](docker/build/README.md)


## Build
### CI Build

The artifacts in this repository are all build by Jenkins. 
The steps can be found in the [Jenkinsfile](Jenkinsfile).

https://jenkins.epa-dev.net/job/eRp/job/eRp/job/vau-image/

### Manual Build
The VAU image and EFI bootloader can be build with docker.

Please read [the documentation](docker/vau/README.md).

#### VAU image - production
1. Add processing-context "release" binary, libraries and configuration files into folder docker/vau/erp
2. Generate the vault secret string (openssl rand -base64 12)
3. Build the image and extract the filesystem:  
```$bash
docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --target production -t production_filesystem docker/vau
docker export $(docker create production_filesystem) --output production_filesystem.tar
tar -xf production_filesystem.tar && rm production_filesystem.tar
```
4. Create squashfs and generate sha512 hash to be used in the efi bootloader
```$bash
mksquashfs production_filesystem/ production_filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery
sha512sum production_filesystem.squashfs
```

#### VAU image - debug
1. Add processing-context "debug" binary, libraries and configuration files into folder docker/vau/debug/erp
2. Generate the vault secret string (openssl rand -base64 12)
3. Prepare a root password ( openssl passwd -6)
4. Build the image and extract the filesystem: 
```$bash
docker build --build-arg "VAULT_SECRET_ID=${VAULT_SECRET_ID}" --build-arg "DEBUG_ROOT_HASH=$DEBUG_ROOT_HASH" --target debug -t debug_filesystem docker/vau
docker export $(docker create debug_filesystem) --output debug_filesystem.tar
tar -xf debug_filesystem.tar && rm debug_filesystem.tar
```
4. Create squashfs and generate sha512 hash to be used in the efi bootloader
```$bash
mksquashfs debug_filesystem/ debug_filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery
sha512sum debug_filesystem.squashfs
```

#### EFI bootloader

Please read [the documentation](docker/efi/README.md).

1. Create db.crt and db.key in docker/efi/certs
2. Build the bootloader
```$bash
    docker build --no-cache\
    --build-arg SQUASHFS_IMAGE_HASH=${sha512sum of the squashfs} \
    --build-arg SQUASHFS_IMAGE_VERSION=${version of the squasfs in NExus} \
    --build-arg RELEASE_TYPE=production \
    -t production_efi \
    docker/efi
```
3. The binary is signed inside the image, extarct it to local filesystem
```$bash
docker cp $(docker create --rm production_efi):pxe-boot.efi.signed pxe-boot.efi.production.signed
```


## Deployment 
Ansile Tower is used for deploying the image.

Update the **vau_image_version** with the version created by the Jenkins build.
The job will prepare the config files into folders matching the MAC address of the VAU server, 
download the efi bootloader at the specified version and switch the symlink defined in /etc/dhcp/dhcpd.conf to the new file.

For more details, see folders /data/local_repo/vau-config/ and /var/lib/tfpd/uefi on the IMGREPO servers. 




