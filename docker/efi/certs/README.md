# Certificates folder

This folder contains the certificate and private keys used to sign the EFI boot image for use with secure boot.

* db.crt - the certificate
* db.key - the public keys

The folder is populated during the build process, with the 2 files, containing values retrieved from Hashicorp Vault.
Optionally, the files can be generated into this folder using openssl.

## Add vault keys from existing files
vault write secret/eRp/environments/rutu/efi/certs_20220201 db.crt=@db-rutu.crt db.key=@db-rutu.key

vault write secret/eRp/environments/pu/efi/certs_20220201 db.crt=@db-pu.crt db.key=@db-pu.key