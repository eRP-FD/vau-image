# ------------------------------------------  PRODUCTION --------------------------------------------------------------

# https://<gitrepo>/eRp/vau-base-image
ARG VAU_BASE_IMAGE_VERSION=v-2.15.0-B00

# Should be the same as what the VAU base image is based on
ARG DEBUG_IMAGE_BASE=de.icr.io/erp_dev/ubuntu-jammy:20250126

FROM de.icr.io/erp_dev/vau-base-image:${VAU_BASE_IMAGE_VERSION} as production

SHELL ["/bin/bash", "-c"]

# Copy files.
COPY files/etc/ /etc/
COPY files/usr/local/bin/* /usr/local/bin/

# Create file structure for aide
RUN mkdir -p /var/config/{erp,haproxy,rsyslog.d} \
    && mkdir -p /var/config/erp/{bin,config,tsl,hsm} \
    && mkdir -p /var/config/haproxy/secrets \
    && touch /var/config/{hosts,dragent.yaml,logdna.conf,vault.json,erp-processing-context,erp-processing-context-secrets,erp-exporter,erp-exporter-secrets} \
    && touch /var/config/erp/bin/erp-processing-context.token \
    && touch /var/config/erp/bin/medication-exporter.token \
    && touch /var/config/erp/config/{POSTGRES_CERTIFICATE,POSTGRES_SSL_CERTIFICATE,POSTGRES_SSL_KEY,TSL_SSL_cert_chain.pem,sslRootCaPath} \
    && touch /var/config/erp/tsl/{tsl-1.xml,tsl-ca.der} \
    && touch /var/config/erp/hsm/work-keyspec \
    && touch /var/config/rsyslog.d/rsyslog-forward.conf \
    && touch /var/config/haproxy/secrets/{redis_password,ca.crt} \
    && touch /var/config/haproxy/haproxy

# Create symlinks for all configs and logging support
RUN mkdir -p /var/log/erp/{9085..9088} /etc/sysconfig /erp/bin \
    && touch /var/log/vau-config.log \
    && ln -fs /var/config/logdna.conf /etc/logdna.conf \
    && ln -fs /var/config/dragent.yaml /opt/draios/etc/dragent.yaml \
    && ln -fs /var/config/haproxy/haproxy /etc/sysconfig/haproxy \
    && ln -sf /var/config/erp/bin/erp-processing-context.token /erp/bin/erp-processing-context.token \
    && ln -sf /var/config/erp/bin/medication-exporter.token /erp/bin/medication-exporter.token

# Add apparmor files
COPY files/etc/apparmor.d/usr.lib.x86_64-linux-gnu.gramine.sgx.loader /etc/apparmor.d/usr.lib.x86_64-linux-gnu.gramine.sgx.loader

# Add non-priviledges user to run PC
RUN useradd -d / -s /usr/sbin/nologin -U -r erp-processing-context
RUN chown -R erp-processing-context:erp-processing-context \
    /erp \
    /var/config \
    /var/log/erp \
    /var/log/vau-config.log \
    /etc/vau-config.pgp

# Remove group and others access
RUN chmod -R go-w /var/config

# Enable services
RUN systemctl enable aesmd \
    vau-config \
    disable-modules \
    sync-logs \
    erp-exporter1.service \
    erp-exporter2.service \
    erp-processing-context-9085.service
#    erp-processing-context-9086.service \
#    erp-processing-context-9087.service \
#    erp-processing-context-9088.service

# Copy application files
COPY --chown=erp-processing-context:erp-processing-context erp /erp

RUN chmod u+x /erp/bin/erp-processing-context /erp/bin/erp-medication-exporter
RUN openssl genrsa -3 -out /etc/enclave-key.pem 3072

# Sign the manifest
WORKDIR /erp/bin
RUN gramine-sgx-sign \
    --manifest /erp/bin/erp-processing-context.manifest \
    --output   /erp/bin/erp-processing-context.manifest.sgx \
    --libpal   /usr/lib/x86_64-linux-gnu/gramine/sgx/libpal.so \
    --key      /etc/enclave-key.pem

RUN gramine-sgx-sign \
    --manifest /erp/bin/exporter.manifest \
    --output   /erp/bin/exporter.manifest.sgx \
    --libpal   /usr/lib/x86_64-linux-gnu/gramine/sgx/libpal.so \
    --key      /etc/enclave-key.pem

## Ubuntu 22.04 + chrony 4.2 will not update time in a container so, a fix is required.
RUN sed -i '/^SYNC_IN_CONTAINER/s/no/yes/' /etc/default/chrony

# Main initialisation script
ARG VAULT_SECRET_ID
RUN sed -i "s|%VAULT_SECRET_ID%|${VAULT_SECRET_ID}|g" /usr/local/bin/vau-config.sh

# Sign the sysdig kernel module (sysdigcloud-probe.ko )
# KERNEL_VERSION is defined in the base image
# Certificates are read from Hashicorp Vault
COPY files/certs/* /boot/
RUN /usr/src/linux-headers-${KERNEL_VERSION}/scripts/sign-file sha256 /boot/db.key /boot/db.crt \
            /lib/modules/${KERNEL_VERSION}/updates/dkms/sysdigcloud-probe.ko

# Remove extra files
RUN rm -rf /boot \
    && rm -f /.dockerenv \
    && rm -f /usr/bin/su

# Create the aide database, all filesystem changes should be done before this step
RUN chmod 644 /etc/logrotate.d/logdna-agent
RUN aide -ic /etc/aide/aide.conf && \
    mv /etc/aide/aide.db.new /etc/aide/aide.db

# ------------------------------------------  DEBUG --------------------------------------------------------------
# Create debug image
# This is not based on the previous layer as apt is not available
FROM ${DEBUG_IMAGE_BASE} as debug

SHELL ["/bin/bash", "-c"]

# Copy users and groups from production VAU image
COPY --from=production /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/

# Install additional debug software
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    ssh \
    vim \
    strace \
    iputils-ping \
    iproute2 \
    apparmor-utils \
    tcpdump \
  && rm -rf /var/lib/apt/lists/*

# Backup users before copying from production
RUN cp -a /etc/passwd /etc/shadow /etc/group /etc/gshadow /root/

# Copy everything else from production VAU image and allow ssh access to debug
COPY --from=production / /

COPY files/debug/debug_sshd.conf /etc/ssh/sshd_config

RUN sed -i '/^COMMIT/i -A INPUT -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT' /etc/iptables/rules.v4

# Restore ssh user and group
RUN mv -f /root/passwd /root/shadow /root/group /root/gshadow /etc/

# Generate a strong password and then generate the hash with the command: openssl passwd -6
ARG DEBUG_ROOT_HASH

RUN echo "root:$DEBUG_ROOT_HASH" | /sbin/chpasswd -e && \
   chage -E -1 root

# Remove part of CIS Hardening section 4.1
RUN sed -i 's/^admin_space_left_action/#admin_space_left_action/' /etc/audit/auditd.conf
RUN echo '*** DEBUG system ***' > /etc/issue.net

# Add TPM/tss tools
ADD files/debug/tpm-tools.tar.gz /root/
RUN echo 'export TPM_INTERFACE_TYPE=dev' >> /root/.bashrc

# Add debug build
# Copy application files
COPY --chown=erp-processing-context:erp-processing-context debug /debug

RUN chmod u+x /debug/erp/bin/erp-processing-context /debug/erp/bin/erp-medication-exporter
RUN mkdir -p /var/config/debug/erp/bin \
  && touch /var/config/debug/erp/bin/erp-processing-context.token \
  && ln -sf /var/config/debug/erp/bin/erp-processing-context.token /debug/erp/bin/erp-processing-context.token \
  && touch /var/config/debug/erp/bin/medication-exporter.token \
  && ln -sf /var/config/debug/erp/bin/medication-exporter.token /debug/erp/bin/medication-exporter.token

# Sign the manifest
WORKDIR /debug/erp/bin
RUN gramine-sgx-sign \
    --manifest /debug/erp/bin/erp-processing-context.manifest \
    --output   /debug/erp/bin/erp-processing-context.manifest.sgx \
    --libpal   /usr/lib/x86_64-linux-gnu/gramine/sgx/libpal.so \
    --key      /etc/enclave-key.pem

RUN gramine-sgx-sign \
    --manifest /debug/erp/bin/exporter.manifest \
    --output   /debug/erp/bin/exporter.manifest.sgx \
    --libpal   /usr/lib/x86_64-linux-gnu/gramine/sgx/libpal.so \
    --key      /etc/enclave-key.pem

# Adjust new path in systemd services
RUN sed -i "s|/erp/bin|/debug/erp/bin|g" /etc/systemd/system/erp*.service /etc/aide/aide.conf

RUN aide -ic /etc/aide/aide.conf && \
    mv /etc/aide/aide.db.new /etc/aide/aide.db
