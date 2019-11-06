FROM resin/amd64-debian:stretch

MAINTAINER Bruno Binet <bruno.binet@helioslite.com>

# enable container init system.
ENV INITSYSTEM on
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

ENV SALT_VERSION 2019.2.2
#ENV REFRESHED_AT 2019-03-07

RUN echo "deb http://repo.saltstack.com/apt/debian/9/amd64/archive/${SALT_VERSION} stretch main" > /etc/apt/sources.list.d/salt.list
ADD https://repo.saltstack.com/apt/debian/9/amd64/archive/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub /tmp/SALTSTACK-GPG-KEY.pub
RUN echo "9e0d77c16ba1fe57dfd7f1c5c2130438  /tmp/SALTSTACK-GPG-KEY.pub" | md5sum --check
RUN apt-key add /tmp/SALTSTACK-GPG-KEY.pub

RUN apt-get update && apt-get install -yq --no-install-recommends \
    dbus vim less net-tools procps lsb-release git openssh-client make gnupg \
    salt-master salt-api python-apt python-git python-openssl \
    python-concurrent.futures python-pip \
    && pip install cherrypy==3.2.3 https://github.com/salt-formulas/reclass/archive/v1.6.0.zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV MOLTEN_VERSION 0.3.1
ENV MOLTEN_MD5 04483620978a3167827bdd1424e34505
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

CMD ["/bin/date"]
