#!/bin/bash
# Validate Cloudformation templates that are located in /templates and /quickstart folders.
# The script requires AWS credentials to be set in the shell and connectivity to AWS.
#==============================================================================
set -e

BASEDIR=$(dirname $0)

cd ${BASEDIR}/..
ABSOLUTE_AWS_DIR=$(pwd)

TEMPLATE_NAME=${1:?"A template name must be specified."}

if [[ "$TEMPLATE_NAME" == *"quickstart-"* ]]; then
    TEMPLATES_PATH="${ABSOLUTE_AWS_DIR}/quickstarts"
else
    TEMPLATES_PATH="${ABSOLUTE_AWS_DIR}/templates"
fi

echo "Validating ${TEMPLATE_NAME}..."
aws cloudformation validate-template --template-body "file://${TEMPLATES_PATH}/${TEMPLATE_NAME}"