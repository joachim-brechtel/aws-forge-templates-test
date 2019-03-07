#!/usr/bin/env bash

set -e


if [[ ! -z "$CI_TASKCAT_USER_GITHUB_PRIVATE_KEY" ]] ; then
    echo "Adding Github private key"
    $(umask  077; echo ${CI_TASKCAT_USER_GITHUB_PRIVATE_KEY} | base64 -d > ~/.ssh/github_id_rsa)
    eval "$(ssh-agent)"
    ssh-add ~/.ssh/github_id_rsa
fi

chmod 744 ./scripts/bootstrap && ./scripts/bootstrap --init