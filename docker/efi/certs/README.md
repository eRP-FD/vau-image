# Certificates folder

This folder contains the certificate and private keys used to sign the EFI boot image for use with secure boot.

* db.crt - the certificate
* db.key - the public keys

The folder is populated during the build process, with the 2 files, containing values retrieved from Hashicorp Vault.
Optionally, the files can be generated into this folder using openssl.