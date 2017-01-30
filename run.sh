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

accept_minion() {
    minion=$1
    key=$2
    if [ -z "${minion}" ] || [ -z "${key}" ]; then
        abort "=> accept_minion 2 args are required (minion, key)."
    fi
    mkdir -p ${SALT_CONFIG}/pki/master/minions
    echo "=> Overwriting minion key: ${minion}"
    echo -e "${key}" > ${SALT_CONFIG}/pki/master/minions/${minion}
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

# create salt master keys
if [ -n "${KEY_MASTER_PRIV}" ]; then
    if [ -z "${KEY_MASTER_PUB}" ]; then
        abort "=> Both KEY_MASTER_PRIV and KEY_MASTER_PUB should be set."
    fi
    echo "=> Overwriting master public & private key"
    mkdir --mode=700 -p ${SALT_CONFIG}/pki/master
    echo -e "${KEY_MASTER_PRIV}" > ${SALT_CONFIG}/pki/master/master.pem
    echo -e "${KEY_MASTER_PUB}" > ${SALT_CONFIG}/pki/master/master.pub
fi

# provision pre-accepted salt minion keys
if [ -z "${PRE_ACCEPT_MINIONS}" ]; then
    echo "=> No minion key supplied: no minion key will be pre-accepted."
else
    for minion in $(echo ${PRE_ACCEPT_MINIONS} | tr "," "\n"); do
        minionkey_var="${minion//-/_}_KEY"
        accept_minion $minion "${!minionkey_var}"
    done
fi

if [ -x "$BEFORE_EXEC_SCRIPT" ]
then
    echo "=> Running BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT]..."
    $BEFORE_EXEC_SCRIPT
    if [ $? -ne 0 ]
    then
        abort "=> BEFORE_EXEC_SCRIPT [$BEFORE_EXEC_SCRIPT] has failed."
    fi
fi

if [ -n "$SALT_API_CMD" ]
then
    echo "=> Running SALT_API_CMD [$SALT_API_CMD]..."
    $SALT_API_CMD
fi

echo "=> Running EXEC_CMD [$EXEC_CMD]..."
exec $EXEC_CMD
