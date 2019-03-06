#!/bin/sh

apk update
apk --no-cache add jq openssh git groff curl
pip --no-cache-dir install awscli taskcat
aws configure set default.aws_secret_access_key ${TASKCAT_SECRET_ACCESS_KEY}
aws configure set default.aws_access_key_id ${TASKCAT_ACCESS_KEY_ID}
aws configure set default.region ${CI_DEFAULT_REGION}
export AWS_SECRET_KEY=${TASKCAT_SECRET_ACCESS_KEY}
export AWS_ACCESS_KEY=${TASKCAT_ACCESS_KEY_ID}
mkdir -p ~/.ssh
echo -e "Host *\n StrictHostKeyChecking no\n UserKnownHostsFile=/dev/null" > ~/.ssh/config
(umask  077 ; echo ${CI_TASKCAT_USER_GITHUB_PRIVATE_KEY} | base64 -d > ~/.ssh/id_rsa)
eval "$(ssh-agent)"
ssh-add ~/.ssh/id_rsa
chmod 744 ./scripts/bootstrap && ./scripts/bootstrap --no-recurse
cd quickstarts
export QS_PROJECT_NAME=quickstart-atlassian-${PRODUCT}
cp -r ./ci/${PRODUCT}/* ./${QS_PROJECT_NAME}/ci/
cd ${QS_PROJECT_NAME}
echo "[{\"ParameterKey\":\"KeyPairName\",\"ParameterValue\":\"$TASKCAT_KEYPAIR_NAME\"}]" > ci/taskcat_project_override.json