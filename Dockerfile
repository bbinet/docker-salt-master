FROM debian:wheezy

MAINTAINER Bruno Binet <bruno.binet@helioslite.com>

ADD salt.list /etc/apt/sources.list.d/salt.list
ADD debian-salt-team-joehealy.gpg.key /tmp/debian-salt-team-joehealy.gpg.key
RUN apt-key add /tmp/debian-salt-team-joehealy.gpg.key && \
  rm /tmp/debian-salt-team-joehealy.gpg.key
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  salt-master python-git python-openssl python-cherrypy3 python-pip

RUN pip install Halite

ADD run.sh /run.sh
RUN chmod a+x /run.sh

VOLUME ["/config"]

# salt-master, halite
EXPOSE 4505 4506 443

ENV EXEC_CMD /usr/bin/salt-master --config /config --log-level debug

CMD ["/run.sh"]
