#!/bin/bash

set -m

if [ -x "$BEFORE_EXEC_SCRIPT" ]
then
    echo "=> Running BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT]..."
    # can be used to add custom users to the docker container
    $BEFORE_EXEC_SCRIPT
    if [ $? -ne 0 ]
    then
        echo "=> BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT] has failed: Abort!"
        exit 1
    fi
fi

if [ -x "$SALT_API_CMD" ]
then
    echo "=> Running SALT_API_CMD [$SALT_API_CMD]..."
    $SALT_API_CMD
fi

echo "=> Running EXEC_CMD [$EXEC_CMD]..."
exec $EXEC_CMD
