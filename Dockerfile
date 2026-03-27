FROM debian:trixie

LABEL maintainer="Bruno Binet <bruno.binet@helioslite.com>"

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

# Switch apt sources to HTTPS
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list.d/debian.sources

# Locale setup
RUN apt-get update && \
    apt-get install -y --no-install-recommends locales && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG=en_US.utf8

# Install system packages
RUN apt-get update && apt-get install -yq --no-install-recommends \
    systemd systemd-sysv dbus \
    vim less net-tools procps lsb-release git patch \
    openssh-client make gnupg curl sudo iproute2 \
    expect ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Salt 3006 via official onedir packages (HTTPS only)
# Uses packages.broadcom.com which must be accessible over HTTPS
ENV SALT_VERSION=3006.23
RUN SALT_BASE_URL=https://packages.broadcom.com/artifactory/saltproject-deb/pool && \
    mkdir -p /tmp/salt-debs && \
    curl -fsSL -o /tmp/salt-debs/salt-common.deb "${SALT_BASE_URL}/salt-common_${SALT_VERSION}_amd64.deb" && \
    curl -fsSL -o /tmp/salt-debs/salt-master.deb "${SALT_BASE_URL}/salt-master_${SALT_VERSION}_amd64.deb" && \
    curl -fsSL -o /tmp/salt-debs/salt-api.deb "${SALT_BASE_URL}/salt-api_${SALT_VERSION}_amd64.deb" && \
    dpkg -i /tmp/salt-debs/salt-common.deb /tmp/salt-debs/salt-master.deb /tmp/salt-debs/salt-api.deb && \
    rm -rf /tmp/salt-debs

# Install reclass using Salt's bundled Python
RUN /opt/saltstack/salt/bin/pip3 install --no-cache-dir \
    https://github.com/salt-formulas/reclass/archive/v1.7.0.zip

# Set default target to multi-user (not graphical)
RUN systemctl set-default multi-user.target

# Mask unnecessary systemd services for container usage
RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    sys-kernel-config.mount \
    display-manager.service \
    getty@.service \
    systemd-logind.service \
    systemd-remount-fs.service \
    getty.target \
    graphical.target

# Fix dbus OOMScoreAdjust (not allowed in containers)
RUN cp /lib/systemd/system/dbus.service /etc/systemd/system/; \
    sed -i 's/OOMScoreAdjust=.*//' /etc/systemd/system/dbus.service

# Install entrypoint and service files
COPY entry.sh /usr/bin/entry.sh
RUN chmod +x /usr/bin/entry.sh
COPY resin.service /etc/systemd/system/resin.service
RUN systemctl enable /etc/systemd/system/resin.service

COPY override.conf /etc/systemd/system/salt-master.service.d/override.conf
COPY pre-salt-master.sh /usr/local/bin/pre-salt-master.sh
RUN chmod +x /usr/local/bin/pre-salt-master.sh

# Molten web UI
ENV MOLTEN_VERSION=0.3.2
ENV MOLTEN_MD5=4bce824944e6a2f5d09d703af53d596d
ADD https://github.com/martinhoefling/molten/releases/download/v${MOLTEN_VERSION}/molten-${MOLTEN_VERSION}.tar.gz molten-${MOLTEN_VERSION}.tar.gz
RUN echo "${MOLTEN_MD5} molten-${MOLTEN_VERSION}.tar.gz" | md5sum --check && \
    mkdir -p /opt/molten && tar -xf molten-${MOLTEN_VERSION}.tar.gz -C /opt/molten --strip-components=1 && \
    rm -f molten-${MOLTEN_VERSION}.tar.gz

# salt-master, salt-api
EXPOSE 4505 4506 443 8000

ENV BEFORE_EXEC_SCRIPT=/etc/salt/before-exec.sh

STOPSIGNAL 37
ENTRYPOINT ["/usr/bin/entry.sh"]
CMD ["/bin/date"]
