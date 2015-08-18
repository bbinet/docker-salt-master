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
  python-git python-openssl python-cherrypy3 python-pip

RUN pip install Halite

ADD run.sh /run.sh
RUN chmod a+x /run.sh

VOLUME ["/config"]

# salt-master, salt-api, halite
EXPOSE 4505 4506 443 4430

ENV BEFORE_EXEC_SCRIPT /config/before-exec.sh
ENV SALT_API_CMD /usr/bin/salt-api -c /config -d
ENV EXEC_CMD /usr/bin/salt-master -c /config -l debug

CMD ["/run.sh"]
