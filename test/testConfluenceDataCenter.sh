#!/bin/bash
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/atl-aws-extensions.sh

DB_PASSWORD="confluence"
DB_MASTER_PASSWORD="postgres"
CONFLUENCE_VERSION="6.0.1"

PARAMS=$(atl_param "AssociatePublicIpAddress" "true")
PARAMS+="~$(atl_param "ConfluenceVersion" "${CONFLUENCE_VERSION}")"
PARAMS+="~$(atl_param "DBMasterUserPassword" "${DB_MASTER_PASSWORD}")"
PARAMS+="~$(atl_param "DBPassword" "${DB_PASSWORD}")"

${BASEDIR}/create-stack.sh "ConfluenceDataCenter.template" "${PARAMS}" "true"
