docker-salt-master
=============

Salt-master docker container.


Build
-----

To create the image `bbinet/salt-master`, execute the following command in the
`docker-salt-master` folder:

    docker build -t bbinet/salt-master .

You can now push the new image to the public registry:
    
    docker push bbinet/salt-master


Run
---

Then, when starting your `salt-master` container, you will want to bind ports
`4505`, `4506` and `443` (salt-api) from the `salt-master` container to a host
external port.

The `salt-master` container will read its configuration and pki stuff from the
`/config` directory volume, so you should bind this config volume to a host
directory or data container.
For example, to run both the salt-api and its Molten Web UI on port 8000, you
can add the following `/config/master.d/api.conf` file:

    external_auth:
      pam:
        myuser:
          - .*
          - '@runner'
          - '@wheel'
          - '@jobs'
    rest_cherrypy:
      port: 8000
      host: 0.0.0.0
      disable_ssl: True
      static: /opt/molten
      static_path: /assets
      app: /opt/molten/index.html
      app_path: /molten

By default, the container will try to run the `/config/before-exec.sh` script,
then the `salt-api`, then the `salt-master`, so you can provide additional
provisioning stuff through this script (like creating new users).

You may also configure the `salt-master` fileserver to be located in another
`/data` volume.

For example:

    $ docker pull bbinet/salt-master

    $ docker run --name salt-master \
        -v /home/salt-master/config:/config \
        -v /home/salt-master/data:/data \
        -p 4505:4505 \
        -p 4506:4506 \
        -p 443:443 \
        bbinet/salt-master
