FROM debian:bookworm

LABEL maintainer="Bruno Binet <bruno.binet@helioslite.com>"

ENV DEBIAN_FRONTEND=noninteractive

# Switch Debian repos to HTTPS
RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources

# Preserve proxy CA cert if injected, then install base dependencies
RUN cp /etc/ssl/certs/ca-certificates.crt /tmp/proxy-ca.crt 2>/dev/null || true && \
  apt-get update && apt-get install -yq --no-install-recommends \
  ca-certificates curl gnupg wget \
  git openssh-client make vim \
  python3 python3-pip python3-apt python3-openssl \
  python3-zmq python3-msgpack python3-jinja2 python3-yaml \
  python3-markupsafe python3-requests python3-distro python3-psutil \
  python3-cherrypy3 python3-pygit2 python3-packaging \
  && rm -rf /var/lib/apt/lists/* && \
  if [ -f /tmp/proxy-ca.crt ]; then \
    cp /tmp/proxy-ca.crt /usr/local/share/ca-certificates/proxy-ca.crt && \
    update-ca-certificates; \
  fi

# Add Freexian Extended LTS repository
RUN wget -qO /usr/share/keyrings/freexian-archive-extended-lts.gpg \
    https://deb.freexian.com/extended-lts/archive-key.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/freexian-archive-extended-lts.gpg] https://deb.freexian.com/extended-lts bookworm main contrib non-free" \
    > /etc/apt/sources.list.d/extended-lts.list

# Install Salt via pip (Broadcom repo not always accessible behind proxies)
ENV SALT_VERSION=3006.9
RUN pip3 install --no-cache-dir --break-system-packages \
  looseversion salt==${SALT_VERSION}

ENV MOLTEN_VERSION=0.3.2
ENV MOLTEN_MD5=4bce824944e6a2f5d09d703af53d596d
ADD https://github.com/martinhoefling/molten/releases/download/v${MOLTEN_VERSION}/molten-${MOLTEN_VERSION}.tar.gz molten-${MOLTEN_VERSION}.tar.gz
RUN echo "${MOLTEN_MD5}  molten-${MOLTEN_VERSION}.tar.gz" | md5sum --check && \
  mkdir -p /opt/molten && tar -xf molten-${MOLTEN_VERSION}.tar.gz -C /opt/molten --strip-components=1 && \
  rm molten-${MOLTEN_VERSION}.tar.gz

ADD run.sh /run.sh
RUN chmod a+x /run.sh

# salt-master, salt-api
EXPOSE 4505 4506 443

ENV SALT_CONFIG=/etc/salt
ENV BEFORE_EXEC_SCRIPT=${SALT_CONFIG}/before-exec.sh
ENV SALT_API_CMD="/usr/local/bin/salt-api -c ${SALT_CONFIG} -d"
ENV EXEC_CMD="/usr/local/bin/salt-master -c ${SALT_CONFIG} --log-file-level=quiet --log-level=info"

CMD ["/run.sh"]
