# Certificates folder

This folder contains the certificate and private keys used to sign the sysdig kernel module (sysdigcloud-probe.ko ) for use with secure boot.

* db.crt - the certificate
* db.key - the public keys

The folder is populated during the build process, with the 2 files, containing values retrieved from Hashicorp Vault.
The certificate and key needs to be the same as the ones that sign the efi.