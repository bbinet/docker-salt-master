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
`4505`, `4506`, and `443` (Halite) from the `salt-master` container to a host
external port.

The `salt-master` container will read its configuration from the `/config`
directory volume, so you should bind this config volume to a host directory or
data container. The `salt-master` will load existing settings for the salt
configuration and pki stuff from this `/config` volume.

By default, the container will try to run the `/config/before_run.sh` script if
it exists before `salt-master` is run, so you can provide additional
provisioning stuff through this script.

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
