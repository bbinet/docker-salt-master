#!/bin/bash

set -m

abort() {
    msg="$1"
    echo "$msg"
    echo "=> Environment was:"
    env
    echo "=> Program terminated!"
    exit 1
}

create_user() {
    user=$1
    password=$2
    if [ -z "${user}" ] || [ -z "${password}" ]; then
        abort "=> create_user 2 args are required (user, password)."
    fi
    useradd ${user}
    echo "${user}:${password}" | chpasswd
    if [ $? -eq 0 ]; then
        echo "=> User \"${user}\" ok."
    else
        abort "=> Failed to create user \"${user}\"!"
    fi
}


# create users from environment variables
if [ -z "${PRE_CREATE_USERS}" ]; then
    echo "=> No user names supplied: no user will be created."
else
    for user in $(echo ${PRE_CREATE_USERS} | tr "," "\n"); do
        userpassword_var="${user}_PASSWORD"
        create_user $user ${!userpassword_var}
    done
fi

if [ -x "$BEFORE_EXEC_SCRIPT" ]
then
    echo "=> Running BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT]..."
    $BEFORE_EXEC_SCRIPT
    if [ $? -ne 0 ]
    then
        echo "=> BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT] has failed: Abort!"
        exit 1
    fi
fi

if [ -n "$SALT_API_CMD" ]
then
    echo "=> Running SALT_API_CMD [$SALT_API_CMD]..."
    $SALT_API_CMD
fi

echo "=> Running EXEC_CMD [$EXEC_CMD]..."
exec $EXEC_CMD
