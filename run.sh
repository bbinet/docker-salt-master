#!/bin/bash

set -m

if [ -x "/config/before_run.sh" ]
then
    # can be used to add custom users to the docker container
    /config/before_run.sh
fi

echo "=> Starting salt-master server..."
exec /usr/bin/salt-master --config /config --log-level debug
