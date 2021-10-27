# Build image

This folder contains a Dockerfile for building an image to be used as an agent by Jenkins, containing squasfs tools for 
creating the filesystem with mksquashfs.

When building locally, this image is not required as long as the 'squashfs-tools' is available locally.

The image is maintained manually:
```bash
cd docker/build
docker build -t de.icr.io/erp_dev/vau-image-build:0.0.1 .
docker push de.icr.io/erp_dev/vau-image-build:0.0.1
``` 

