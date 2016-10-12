#!/bin/bash
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/atl-aws-extensions.sh

KEY_PAIR=${PEMFILE:-$(atl_getKeyName)}
if [[ -z ${KEY_PAIR} ]]; then
  echo "No key pair found. Create one now for region '${AWS_REGION}'?"
  KEY_PAIR=$(atl_createKeyPair)
  if [[ -z ${KEY_PAIR} ]]; then
    echo "Env variable PEMFILE not set. Set it to your Key Pair name for region '${AWS_REGION}'"  
    atl_propUsage "key"
    exit 1
  fi
  atl_addProp "key" "${KEY_PAIR}"
fi

cd ${BASEDIR}/..
ABSOLUTE_AWS_DIR=$(pwd)

TEMPLATES_PATH="${ABSOLUTE_AWS_DIR}/templates"
S3_BUCKET=${2:-aws-deployment-test}
S3_BUCKET_LINK="s3://${S3_BUCKET}"
S3_URL="https://${S3_BUCKET}.s3.amazonaws.com"

echo "Copying $1 to S3"
aws s3 cp "${TEMPLATES_PATH}/$1" "${S3_BUCKET_LINK}/${KEY_PAIR}-$1"
echo "Validating..."
aws cloudformation validate-template --template-url "${S3_URL}/${KEY_PAIR}-$1"
