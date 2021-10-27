# The OS image

## Intro

This folder contains the files to build the squasfs filesystem.

To build the operating system, a docker image is first build (vau-base-image)
then the files are extracted from inside the built image, and a squashfs files is created, that will ultimately boot as
the OS on the VAU servers.

## Base image

The current Dockerfile uses another custom image as the base image, more information on the base hardened image can
be found in it's repository: https://github.ibmgcloud.net/eRp/vau-base-image

The required software and kernel are installed in the base image, the purpose of this image is to add the processing context files
and related files and configs.

## Processing context

The dockerfile looks for 2 folders, which are created and populated by the Jenkins CI. The 2 folders are:
 - vau/erp - should contain processing context binary, libraries, configuration - this build is a "release build"
 - vau/debug/erp  - should contain processing context binary, libraries, configuration - this build is a "debug build"

The archives with the files above are fetched from Nexus and unarchived in the locations above, to be copied inside the docker image.
This is aconplished using a gradle task, that can also be ran separately:
```$bash
./gradlew extractApp
```

For builds independently of Jenkins, please make sure the processing context files are present in the folders above,
so they can be copied inside the image.

## System configuration files

Please read [the files/README.md ](files/README.md)

## Configuration and secrets management

As the image build here is meant to run in any environment, configuration files specific to each environment, or deployment zone,
are downloaded after boot, from a webserver,
and placed into the specific locations. Please see the logic in the [the vau-config script](files/usr/local/bin/vau-config.sh)

Nameservers, hostname, and other information are received via DHCP.

The webserver to download the files from, is deducted from the DHCP information received.
Files then are downloaded from a folder matching the server's MAC address, alongs with a signed file containing file checksums.
The checksums file signature is validated via gpg, and then each file's integrity is checked with sha256sum.
The files are then placed in specific folders, which have already been created at build time and are present in the aide database.

For the secrets, a secret ID is generated during build (VAULT_SECRET_ID). This secret will only be enabled for a
limited timeframe and once usage by the deployment job. Same as for the configuration files, the secrets are read from the Vault and placed
at specific locations.


## Production image

The production image is based on the [base image](https://github.ibmgcloud.net/eRp/vau-base-image) , which installs
most of the software.

The image in this repository
- creates the file structure and symlinks to configuration files, which are downloaded after boot.
This is done because [aide](https://aide.github.io) is used to verify the file and directory integrity.
The database is created at the end of the dockerfile.
- copies system configuration [files](files/README.md)
- adds the [AppArmor](https://wiki.debian.org/AppArmor) profile for the processing-context.
- creates the 'erp-processing-context' linux user, and sets permissions
- enables the required systemd services
- copies the application files, generates a gramine key and signs the manifest file
- creates the [aide](https://aide.github.io) database

## Debug image

The debug image is not based on the above image, but start off with a clean ubuntu, and copies all files from the production image.
As this image is meant to be used for debugging, it enables ssh access, installs debug tools,and also containes a "debug" version of the procesing-context.
