# Scripts

Contains the main script executed by the EFI bootloader.

The script will load necessary modules, configure network, download the squasfs image, and mount required filesystem.

The squasfs image is downloaded from a Nexus repository, and a checksum is performed on the image.

Please note the script contains placeholders, in this format %PLACEHOLDER%, which are replaced in the Dockerfile. 


