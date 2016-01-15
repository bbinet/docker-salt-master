FROM debian:wheezy

MAINTAINER Bruno Binet <bruno.binet@helioslite.com>

ENV DEBIAN_FRONTEND noninteractive

RUN echo "deb http://debian.saltstack.com/debian wheezy-saltstack-2015-05 main" > /etc/apt/sources.list.d/salt.list
ADD debian-salt-team-joehealy.gpg.key /tmp/debian-salt-team-joehealy.gpg.key
RUN apt-key add /tmp/debian-salt-team-joehealy.gpg.key && \
  rm /tmp/debian-salt-team-joehealy.gpg.key

ENV SALT_VERSION 2015.5.3+ds-1~bpo70+2
RUN apt-get update && apt-get install -yq --no-install-recommends \
  salt-master=${SALT_VERSION} salt-api=${SALT_VERSION} \
  python-git python-openssl python-cherrypy3

ENV MOLTEN_VERSION 0.2.0
ENV MOLTEN_MD5 d9c247637c53f433d9a8e03ea7e97ba8
ADD https://github.com/martinhoefling/molten/releases/download/v${MOLTEN_VERSION}/molten-${MOLTEN_VERSION}.tar.gz molten-${MOLTEN_VERSION}.tar.gz
RUN echo "${MOLTEN_MD5}  molten-${MOLTEN_VERSION}.tar.gz" | md5sum --check
RUN mkdir -p /opt/molten && tar -xf molten-${MOLTEN_VERSION}.tar.gz -C /opt/molten --strip-components=1

ADD run.sh /run.sh
RUN chmod a+x /run.sh

VOLUME ["/config"]

# salt-master, salt-api
EXPOSE 4505 4506 443

ENV BEFORE_EXEC_SCRIPT /config/before-exec.sh
ENV SALT_API_CMD /usr/bin/salt-api -c /config -d
ENV EXEC_CMD /usr/bin/salt-master -c /config -l debug

CMD ["/run.sh"]
