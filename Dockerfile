FROM balenalib/amd64-debian:buster

MAINTAINER Bruno Binet <bruno.binet@helioslite.com>

# enable container init system.
ENV container docker
ENV INITSYSTEM on
ENV UDEV on
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

ENV SALT_VERSION 2019.2.7
#ENV REFRESHED_AT 2019-05-06

RUN echo "deb http://repo.saltstack.com/py3/debian/10/amd64/archive/${SALT_VERSION} buster main" > /etc/apt/sources.list.d/salt.list
ADD https://repo.saltstack.com/py3/debian/10/amd64/archive/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub /tmp/SALTSTACK-GPG-KEY.pub
RUN echo "9e0d77c16ba1fe57dfd7f1c5c2130438  /tmp/SALTSTACK-GPG-KEY.pub" | md5sum --check
RUN apt-key add /tmp/SALTSTACK-GPG-KEY.pub

RUN apt-get update && apt-get install -yq --no-install-recommends systemd \
    systemd-sysv dbus vim less net-tools procps lsb-release git \
    openssh-client make gnupg salt-master salt-api python3-apt python3-git \
    python3-openssl python3-pip python3-setuptools python3-wheel \
    && pip3 install CherryPy https://github.com/bbinet/reclass/archive/helioslite.zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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
