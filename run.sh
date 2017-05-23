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

# create users from environment variables and docker secrets
if [ -z "${PRE_CREATE_USERS}" ]; then
    echo "=> No user names supplied: no user will be created."
else
    for user in $(echo ${PRE_CREATE_USERS} | tr "," "\n"); do
        if [ -f "/run/secrets/${user}.password" ]
        then
            create_user $user $(cat "/run/secrets/${user}.password")
        else
            userpassword_var="${user}_PASSWORD"
            create_user $user ${!userpassword_var}
        fi
    done
fi

# create salt master keys from env variables
if [ -n "${KEY_MASTER_PRIV}" ]; then
    if [ -z "${KEY_MASTER_PUB}" ]; then
        abort "=> Both KEY_MASTER_PRIV and KEY_MASTER_PUB should be set."
    fi
    echo "=> Overwriting master public & private key"
    mkdir -p "${SALT_CONFIG}/pki/master"
    chmod 700 "${SALT_CONFIG}/pki/master"
    echo -e "${KEY_MASTER_PRIV}" > "${SALT_CONFIG}/pki/master/master.pem"
    echo -e "${KEY_MASTER_PUB}" > "${SALT_CONFIG}/pki/master/master.pub"
fi

# create salt master keys from docker secrets
if [ -f /run/secrets/master.pem ] && [ -f /run/secrets/master.pub ]
then
    mkdir -p "${SALT_CONFIG}/pki/master"
    chmod 700 "${SALT_CONFIG}/pki/master"
    echo "=> Overwriting master public & private key from docker secrets"
    cp /run/secrets/master.pem "${SALT_CONFIG}/pki/master/master.pem"
    cp /run/secrets/master.pub "${SALT_CONFIG}/pki/master/master.pub"
fi

if [ -f "${SALT_CONFIG}/pki/master/master.pem" ]
then
    if [ -z "${PRE_ACCEPT_MINIONS}" ]; then
        echo "=> No minion key supplied: no minion key will be pre-accepted."
    else
        for minion in $(echo ${PRE_ACCEPT_MINIONS} | tr "," "\n"); do
            mkdir -p "${SALT_CONFIG}/pki/master/minions"
            minionkey_var="${minion//-/_}_KEY"
            if [ -f "/run/secrets/${minion}.pub" ]
            then
                echo "=> Overwriting minion ${minion} key from docker secrets"
                cp "/run/secrets/${minion}.pub" "${SALT_CONFIG}/pki/master/minions/${minion}"
            elif ! [ -z "${!minionkey_var}" ]
            then
                echo "=> Overwriting minion ${minion} key from env variables"
                echo -e "${!minionkey_var}" > "${SALT_CONFIG}/pki/master/minions/${minion}"
            else
                abort "=> Failed to preaccept minion \"${minion}\"!"
            fi
        done
    fi
fi

if [ -x "${BEFORE_EXEC_SCRIPT%% *}" ]
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
