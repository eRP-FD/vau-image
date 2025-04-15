#!/bin/bash
set -e
set -o pipefail

# define funcions
setup_processing_context () {

echo "Disabling exporter as we'll be running processing context for ${HOST_MAC_ADDRESS}"  >> /var/log/vau-config.log
systemctl disable erp-exporter1 erp-exporter2
systemctl stop erp-exporter1 erp-exporter2

echo "Starting download of configs for ${HOST_MAC_ADDRESS} in ${VAU_CONFIG_DIR}" >> /var/log/vau-config.log

echo "Downloading file checksums and signature ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
wget ${IMGREPO_IP}/vau-config/${HOST_MAC_ADDRESS}.sha256sums -O SHA256SUMS
wget ${IMGREPO_IP}/vau-config/${HOST_MAC_ADDRESS}.sha256sums.gpg -O SHA256SUMS.gpg

echo "Downloading configs for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
mkdir -p ${HOST_MAC_ADDRESS}/{tsl,haproxy}
wget ${VAU_CONFIG_URI}/erp-processing-context.env -O ${HOST_MAC_ADDRESS}/erp-processing-context.env
wget ${VAU_CONFIG_URI}/POSTGRES_CERTIFICATE -O ${HOST_MAC_ADDRESS}/POSTGRES_CERTIFICATE
wget ${VAU_CONFIG_URI}/POSTGRES_SSL_CERTIFICATE -O ${HOST_MAC_ADDRESS}/POSTGRES_SSL_CERTIFICATE

wget ${VAU_CONFIG_URI}/sslRootCaPath -O ${HOST_MAC_ADDRESS}/sslRootCaPath
wget ${VAU_CONFIG_URI}/TSL_SSL_cert_chain.pem -O ${HOST_MAC_ADDRESS}/TSL_SSL_cert_chain.pem

wget ${VAU_CONFIG_URI}/rsyslog-forward.conf -O ${HOST_MAC_ADDRESS}/rsyslog-forward.conf
wget ${VAU_CONFIG_URI}/dragent.yaml -O ${HOST_MAC_ADDRESS}/dragent.yaml

wget ${VAU_CONFIG_URI}/tsl/tsl-1.xml -O ${HOST_MAC_ADDRESS}/tsl/tsl-1.xml
wget ${VAU_CONFIG_URI}/tsl/tsl-ca.der -O ${HOST_MAC_ADDRESS}/tsl/tsl-ca.der

wget ${VAU_CONFIG_URI}/haproxy/haproxy.env -O ${HOST_MAC_ADDRESS}/haproxy/haproxy.env
wget ${VAU_CONFIG_URI}/haproxy/ca.crt -O ${HOST_MAC_ADDRESS}/haproxy/ca.crt

wget ${VAU_CONFIG_URI}/vault.json -O ${HOST_MAC_ADDRESS}/vault.json
wget ${VAU_CONFIG_URI}/hosts -O ${HOST_MAC_ADDRESS}/hosts

echo "Performing GPG signature verification of downloaded files ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
GNUPGHOME=$VAU_CONFIG_DIR
export GNUPGHOME
gpg --import /etc/vau-config.pgp
gpg --verify SHA256SUMS.gpg SHA256SUMS
sha256sum --check --ignore-missing --strict SHA256SUMS

echo "Copying configs for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log

#vault
cp ${HOST_MAC_ADDRESS}/vault.json /var/config/vault.json

# hosts
cp ${HOST_MAC_ADDRESS}/hosts /var/config/hosts

# processing-context
cp ${HOST_MAC_ADDRESS}/erp-processing-context.env /var/config/erp-processing-context
cp ${HOST_MAC_ADDRESS}/POSTGRES_CERTIFICATE /var/config/erp/config/POSTGRES_CERTIFICATE
cp ${HOST_MAC_ADDRESS}/POSTGRES_SSL_CERTIFICATE /var/config/erp/config/POSTGRES_SSL_CERTIFICATE
cp ${HOST_MAC_ADDRESS}/sslRootCaPath /var/config/erp/config/sslRootCaPath
cp ${HOST_MAC_ADDRESS}/TSL_SSL_cert_chain.pem /var/config/erp/config/TSL_SSL_cert_chain.pem

# TSL
cp ${HOST_MAC_ADDRESS}/tsl/tsl-1.xml /var/config/erp/tsl/tsl-1.xml
cp ${HOST_MAC_ADDRESS}/tsl/tsl-ca.der /var/config/erp/tsl/tsl-ca.der

#rsyslog
cp ${HOST_MAC_ADDRESS}/rsyslog-forward.conf /var/config/rsyslog.d/rsyslog-forward.conf

#sysdig
cp ${HOST_MAC_ADDRESS}/dragent.yaml /var/config/dragent.yaml

#haproxy
cp ${HOST_MAC_ADDRESS}/haproxy/haproxy.env /var/config/haproxy/haproxy
cp ${HOST_MAC_ADDRESS}/haproxy/ca.crt /var/config/haproxy/secrets/ca.crt

echo "Configs successfully downloaded for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log

echo "Starting vault integration " >> /var/log/vau-config.log

ROLE_ID=$(jq -r '.data.role_id' /var/config/vault.json) #get the role id of the app role
export VAULT_ADDR="https://${IMGREPO_IP}:8200"
export VAULT_SKIP_VERIFY=true

echo "Using vault role ${ROLE_ID} at address ${VAULT_ADDR}" >> /var/log/vau-config.log
export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=%VAULT_SECRET_ID%)
vault read -format=json secret/${HOST_MAC_ADDRESS} | jq -r '.data | to_entries[] | .key + "=\"" + (.value|tostring) + "\""' >> /var/config/erp-processing-context-secrets

echo "Secrets successfully loaded from the vault" >> /var/log/vau-config.log

# create individual files from secrets where required
source /var/config/erp-processing-context-secrets


printf %s "$HSM_WORK_KEYSPEC" > /var/config/erp/hsm/work-keyspec
printf %s "$REDIS_PASSWORD" > /var/config/haproxy/secrets/redis_password
printf %s "$POSTGRES_SSL_KEY" > /var/config/erp/config/POSTGRES_SSL_KEY
chmod 600 /var/config/erp/config/POSTGRES_SSL_KEY

# restore ownership after switching vau-config.service from erp-processing-context to root
chown -R erp-processing-context:erp-processing-context /var/config

}

setup_exporter () {

echo "Disabling processing context as we'll be running exporter for ${HOST_MAC_ADDRESS}"  >> /var/log/vau-config.log
systemctl disable erp-processing-context-9085.service
systemctl stop erp-processing-context-9085.service

echo "Starting download of configs for ${HOST_MAC_ADDRESS} in ${VAU_CONFIG_DIR}" >> /var/log/vau-config.log

echo "Downloading file checksums and signature ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
wget ${IMGREPO_IP}/vau-config/${HOST_MAC_ADDRESS}.sha256sums -O SHA256SUMS
wget ${IMGREPO_IP}/vau-config/${HOST_MAC_ADDRESS}.sha256sums.gpg -O SHA256SUMS.gpg

echo "Downloading configs for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
mkdir -p ${HOST_MAC_ADDRESS}/{tsl,haproxy}
wget ${VAU_CONFIG_URI}/erp-processing-context.env -O ${HOST_MAC_ADDRESS}/erp-processing-context.env
wget ${VAU_CONFIG_URI}/erp-exporter -O ${HOST_MAC_ADDRESS}/erp-exporter
wget ${VAU_CONFIG_URI}/SerNo2TID.csv -O ${HOST_MAC_ADDRESS}/SerNo2TID.csv || true
wget ${VAU_CONFIG_URI}/POSTGRES_CERTIFICATE -O ${HOST_MAC_ADDRESS}/POSTGRES_CERTIFICATE
wget ${VAU_CONFIG_URI}/POSTGRES_SSL_CERTIFICATE -O ${HOST_MAC_ADDRESS}/POSTGRES_SSL_CERTIFICATE

wget ${VAU_CONFIG_URI}/sslRootCaPath -O ${HOST_MAC_ADDRESS}/sslRootCaPath
wget ${VAU_CONFIG_URI}/TSL_SSL_cert_chain.pem -O ${HOST_MAC_ADDRESS}/TSL_SSL_cert_chain.pem

wget ${VAU_CONFIG_URI}/rsyslog-forward.conf -O ${HOST_MAC_ADDRESS}/rsyslog-forward.conf
wget ${VAU_CONFIG_URI}/dragent.yaml -O ${HOST_MAC_ADDRESS}/dragent.yaml

wget ${VAU_CONFIG_URI}/tsl/tsl-1.xml -O ${HOST_MAC_ADDRESS}/tsl/tsl-1.xml
wget ${VAU_CONFIG_URI}/tsl/tsl-ca.der -O ${HOST_MAC_ADDRESS}/tsl/tsl-ca.der

wget ${VAU_CONFIG_URI}/haproxy/haproxy.env -O ${HOST_MAC_ADDRESS}/haproxy/haproxy.env
wget ${VAU_CONFIG_URI}/haproxy/ca.crt -O ${HOST_MAC_ADDRESS}/haproxy/ca.crt

wget ${VAU_CONFIG_URI}/vault.json -O ${HOST_MAC_ADDRESS}/vault.json
wget ${VAU_CONFIG_URI}/hosts -O ${HOST_MAC_ADDRESS}/hosts

echo "Performing GPG signature verification of downloaded files ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
GNUPGHOME=$VAU_CONFIG_DIR
export GNUPGHOME
gpg --import /etc/vau-config.pgp
gpg --verify SHA256SUMS.gpg SHA256SUMS
sha256sum --check --ignore-missing --strict SHA256SUMS

echo "Copying configs for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log

#vault
cp ${HOST_MAC_ADDRESS}/vault.json /var/config/vault.json

# hosts
cp ${HOST_MAC_ADDRESS}/hosts /var/config/hosts

# medication-exporter
cp ${HOST_MAC_ADDRESS}/erp-processing-context.env /var/config/erp-processing-context
cp ${HOST_MAC_ADDRESS}/erp-exporter /var/config/erp-exporter
cp ${HOST_MAC_ADDRESS}/SerNo2TID.csv /var/config/erp/config/SerNo2TID.csv || true
cp ${HOST_MAC_ADDRESS}/POSTGRES_CERTIFICATE /var/config/erp/config/POSTGRES_CERTIFICATE
cp ${HOST_MAC_ADDRESS}/POSTGRES_SSL_CERTIFICATE /var/config/erp/config/POSTGRES_SSL_CERTIFICATE
cp ${HOST_MAC_ADDRESS}/sslRootCaPath /var/config/erp/config/sslRootCaPath
cp ${HOST_MAC_ADDRESS}/TSL_SSL_cert_chain.pem /var/config/erp/config/TSL_SSL_cert_chain.pem

# TSL
cp ${HOST_MAC_ADDRESS}/tsl/tsl-1.xml /var/config/erp/tsl/tsl-1.xml
cp ${HOST_MAC_ADDRESS}/tsl/tsl-ca.der /var/config/erp/tsl/tsl-ca.der

#rsyslog
cp ${HOST_MAC_ADDRESS}/rsyslog-forward.conf /var/config/rsyslog.d/rsyslog-forward.conf

#sysdig
cp ${HOST_MAC_ADDRESS}/dragent.yaml /var/config/dragent.yaml

#haproxy
cp ${HOST_MAC_ADDRESS}/haproxy/haproxy.env /var/config/haproxy/haproxy
cp ${HOST_MAC_ADDRESS}/haproxy/ca.crt /var/config/haproxy/secrets/ca.crt

echo "Configs successfully downloaded for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log

echo "Starting vault integration " >> /var/log/vau-config.log

ROLE_ID=$(jq -r '.data.role_id' /var/config/vault.json) #get the role id of the app role
export VAULT_ADDR="https://${IMGREPO_IP}:8200"
export VAULT_SKIP_VERIFY=true

echo "Using vault role ${ROLE_ID} at address ${VAULT_ADDR}" >> /var/log/vau-config.log
export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=%VAULT_SECRET_ID%)
vault read -format=json secret/${HOST_MAC_ADDRESS} | jq -r '.data | to_entries[] | .key + "=\"" + (.value|tostring) + "\""' >> /var/config/erp-exporter-secrets

echo "Secrets successfully loaded from the vault" >> /var/log/vau-config.log

# create individual files from secrets where required
source /var/config/erp-exporter-secrets


printf %s "$HSM_WORK_KEYSPEC" > /var/config/erp/hsm/work-keyspec
printf %s "$REDIS_PASSWORD" > /var/config/haproxy/secrets/redis_password
printf %s "$POSTGRES_SSL_KEY" > /var/config/erp/config/POSTGRES_SSL_KEY
chmod 600 /var/config/erp/config/POSTGRES_SSL_KEY

# restore ownership after switching vau-config.service from erp-processing-context to root
chown -R erp-processing-context:erp-processing-context /var/config

}

# get MAC address to be used as config identifier
HOST_MAC_ADDRESS=$(cat /sys/class/net/bond1/address | tr ':' '-')
echo "Starting configuration provisioning for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log

# add hostname to /etc/hosts to speed up rsyslog startup
printf "$(grep -E 'fixed-address|host-name' /var/lib/dhcp/dhclient.leases | head -n2 | sed -e 's/^.* //' -e 's/;//' -e 's/"//g' | sort | tr '\n' ' ')\n" >> /etc/hosts

# get IMGREPO IP
IMGREPO_IP="$(grep dhcp-server-identifier /var/lib/dhcp/dhclient.leases | uniq | cut -d' ' -f5 | cut -d';' -f1)"
VAU_CONFIG_URI="${IMGREPO_IP}/vau-config/${HOST_MAC_ADDRESS}"

echo "Setting config download URI to ${VAU_CONFIG_URI}" >> /var/log/vau-config.log

# set permissions for new files added
umask 037

# create working dir
VAU_CONFIG_DIR=$(mktemp -d)
cd $VAU_CONFIG_DIR
mkdir ${HOST_MAC_ADDRESS}

# setting up logdna
# logdna to be disabled if boot date is after 1743321600 - Mar 30th, 08:00UTC
if [[ $(date '+%s') > 1743321600 ]]
then
        echo "logdna-agent.service will be disabled on ${HOST_MAC_ADDRESS} as we're booting after discontinuation date"  >> /var/log/vau-config.log
        systemctl disable logdna-agent.service
        systemctl stop logdna-agent.service
        echo "logdna-agent.service disabled and stopped on ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
else
        echo "logdna-agent.service will be enabled and started on ${HOST_MAC_ADDRESS} as we're booting before discontinuation date"  >> /var/log/vau-config.log
        wget ${VAU_CONFIG_URI}/logdna.conf -O ${HOST_MAC_ADDRESS}/logdna.conf
        cp ${HOST_MAC_ADDRESS}/logdna.conf /var/config/logdna.conf
        systemctl enable logdna-agent.service
        systemctl start logdna-agent.service
        echo "logdna-agent.service enabled and started on ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
fi

# set up Cloud Logs agent
wget ${VAU_CONFIG_URI}/fluent-bit.conf -O ${HOST_MAC_ADDRESS}/fluent-bit.conf
wget ${VAU_CONFIG_URI}/fluent-bit-secrets  -O ${HOST_MAC_ADDRESS}/fluent-bit-secrets
wget ${VAU_CONFIG_URI}/parsers.conf  -O ${HOST_MAC_ADDRESS}/parsers.conf
cp ${HOST_MAC_ADDRESS}/fluent-bit.conf /var/config/fluent-bit.conf
cp ${HOST_MAC_ADDRESS}/fluent-bit-secrets /var/config/fluent-bit-secrets
cp ${HOST_MAC_ADDRESS}/parsers.conf /var/config/parsers.conf
systemctl enable fluent-bit.service
systemctl start fluent-bit.service
echo "fluent-bit.service enabled and started on ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log

# get config files based on role (exporter or processing context)
echo "Getting role for ${HOST_MAC_ADDRESS}" >> /var/log/vau-config.log
wget ${VAU_CONFIG_URI}/role || true
if ( grep -qs exporter role )
then
        echo "${HOST_MAC_ADDRESS} will be set up as exporter" >> /var/log/vau-config.log
        setup_exporter
else
        echo "${HOST_MAC_ADDRESS} will be set up as processing context" >> /var/log/vau-config.log
        setup_processing_context
fi

exit 0
