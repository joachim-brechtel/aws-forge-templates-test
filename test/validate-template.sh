#!/bin/bash
set -e

BASEDIR=$(dirname $0)

cd ${BASEDIR}/..
ABSOLUTE_AWS_DIR=$(pwd)

TEMPLATE_NAME=${1:?"A template name must be specified."}
TEMPLATES_PATH="${ABSOLUTE_AWS_DIR}/templates"

echo "Validating ${TEMPLATE_NAME}..."
aws cloudformation validate-template --template-body "file://${TEMPLATES_PATH}/${TEMPLATE_NAME}"