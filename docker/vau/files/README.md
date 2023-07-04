# File structure

## Debug folder
This folder contains configurations for the debug image (e.g - re-enabling ssh)

## etc folder
The structure under files folder is meant to emulate the root "/etc" folder on the server.

Contains different configuration files to be copied into the /etc folder in the image.
- /etc/apparmor.d/ - [AppArmor](https://wiki.debian.org/AppArmor) profile for the processing-context process running under gramine
- /etc/haproxy/haproxy.cfg - the haproxy configuration file, with some values read from the environment
- /etc/systemd/system - systemd service definition files
    - disable-modules - oneshot service to disable kernel module loading after boot
    - erp-processing-context-9085-8 - systemd unit definitions for the processing-context binary started with gramine
    - sync-logs - oneshot service to make boot logs available to logdna
    - vau-config - oneshot service responsible for downloading configuration files and secrets from Hashicorp Vault
    For more information, please see [the script](usr/local/bin/vau-config.sh)
- /etc/udev/rules.d - udev rules for configuring access to tpm and gramine/sgx devices
- /etc/vau-config.pgp - the pgp public key used to verify the integrity of the configuration files

## usr folder

Contains script and binaries:
- redis-cli - used by haproxy to check redis connectivity in redis-healthcheck.sh
- redis-healthcheck.sh - used by haproxy to check redis backends health
- vau-config.sh - main bash script for configuring the system after boot
