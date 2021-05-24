FROM balenalib/amd64-debian:buster

MAINTAINER Bruno Binet <bruno.binet@helioslite.com>

# enable container init system.
ENV container docker
ENV INITSYSTEM on
ENV UDEV on
ENV DEBIAN_FRONTEND noninteractive

ENV SALT_VERSION 3003
#ENV REFRESHED_AT 2019-05-06

# make the "en_US.UTF-8" locale so supervisor will be utf-8 enabled by default
# see: https://github.com/docker-library/postgres/blob/master/13/Dockerfile#L47-L57
RUN set -eux; \
       if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
# if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
               grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
               sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
               ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
       fi; \
       if [ -f /etc/dpkg/dpkg.cfg.d/01_nodoc ]; then \
               grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/01_nodoc; \
               sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/01_nodoc; \
               ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/01_nodoc; \
       fi; \
       apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
       localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN curl -fsSL -o /usr/share/keyrings/salt-archive-keyring.gpg https://repo.saltproject.io/py3/debian/10/amd64/${SALT_VERSION}/salt-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/salt-archive-keyring.gpg] https://repo.saltproject.io/py3/debian/10/amd64/${SALT_VERSION} buster main" | sudo tee /etc/apt/sources.list.d/salt.list

RUN apt-get update && apt-get install -yq --no-install-recommends systemd \
    systemd-sysv dbus vim less net-tools procps lsb-release git patch \
    openssh-client make gnupg salt-master salt-api python3-apt python3-git \
    python3-openssl python3-pip python3-setuptools python3-wheel expect \
    && pip3 install CherryPy https://github.com/salt-formulas/reclass/archive/v1.7.0.zip \
    && rm -rf /var/lib/apt/lists/*

# Dirty fix issue https://github.com/saltstack/salt/issues/59990
# (reverting: https://github.com/saltstack/salt/pull/59866)
COPY salt_v3003_master_tops.patch /tmp/salt_v3003_master_tops.patch
RUN patch /usr/lib/python3/dist-packages/salt/master.py /tmp/salt_v3003_master_tops.patch 

# We never want these to run in a container
# Feel free to edit the list but this is the one we used
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
COPY entry.sh /usr/bin/entry.sh
COPY resin.service /etc/systemd/system/resin.service
RUN systemctl enable /etc/systemd/system/resin.service

ENV MOLTEN_VERSION 0.3.2
ENV MOLTEN_MD5 4bce824944e6a2f5d09d703af53d596d
ADD https://github.com/martinhoefling/molten/releases/download/v${MOLTEN_VERSION}/molten-${MOLTEN_VERSION}.tar.gz molten-${MOLTEN_VERSION}.tar.gz
RUN echo "${MOLTEN_MD5}  molten-${MOLTEN_VERSION}.tar.gz" | md5sum --check
RUN mkdir -p /opt/molten && tar -xf molten-${MOLTEN_VERSION}.tar.gz -C /opt/molten --strip-components=1

RUN cp /lib/systemd/system/dbus.service /etc/systemd/system/; \
    sed -i 's/OOMScoreAdjust=.*//' /etc/systemd/system/dbus.service

COPY override.conf /etc/systemd/system/salt-master.service.d/override.conf
COPY pre-salt-master.sh /usr/local/bin/pre-salt-master.sh

#VOLUME /sys/fs/cgroup

# salt-master, salt-api
EXPOSE 4505 4506 443

ENV BEFORE_EXEC_SCRIPT /etc/salt/before-exec.sh

STOPSIGNAL 37
VOLUME ["/sys/fs/cgroup"]
ENTRYPOINT ["/usr/bin/entry.sh"]

CMD ["/bin/date"]
