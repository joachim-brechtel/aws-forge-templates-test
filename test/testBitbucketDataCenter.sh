#!/bin/bash
set -e

BASEDIR=$(dirname $0)
source $BASEDIR/atl-aws-extensions.sh

DB_PASSWORD="stash"
DB_MASTER_PASSWORD="postgres"
BITBUCKET_VERSION="4.10.0"

EBS_SNAPSHOT=${snapshot}
RDS_SNAPSHOT=${rds_snapshot}
FILE_SERVER_INSTANCE_TYPE=${fileserverinstancetype}
VOLUME_TYPE=${volumetype}

# Optional Standby Parameters:
# PRIMARY_REGION="ap-southeast-2"
# AWS_ACCOUNT=""
# RDS_MASTER=""
# STANDBY_DB_MASTER=$(atl_param "DBMaster" "arn:aws:rds:${PRIMARY_REGION}:${AWS_ACCOUNT}:db:${RDS_MASTER}")
# SSL_CERTIFICATE=$(atl_param "SSLCertificateName" "wildcard.internal.atlassian.com")

PARAMS="$(atl_param "AssociatePublicIpAddress" "true")"
PARAMS+="~$(atl_param "BitbucketProperties" "plugin.bitbucket-scm-cache.refs.enabled=true")"
PARAMS+="~$(atl_param "BitbucketVersion" "${BITBUCKET_VERSION}")"
PARAMS+="~$(atl_param "DBMasterUserPassword" "${DB_MASTER_PASSWORD}")"
PARAMS+="~$(atl_param "DBPassword" "${DB_PASSWORD}")"
PARAMS+="~$(atl_param "HomeSize" "300")"
PARAMS+="~$(atl_param "CidrBlock" "0.0.0.0/0")"
PARAMS+="~$(atl_param "StartCollectd" "true")"

if [[ -n ${FILE_SERVER_INSTANCE_TYPE} ]]; then
    PARAMS+="~$(atl_param "FileServerInstanceType" "${FILE_SERVER_INSTANCE_TYPE}")"
fi
if [[ -n ${VOLUME_TYPE} ]]; then
    PARAMS+="~$(atl_param "HomeVolumeType" "${VOLUME_TYPE}")"
fi
if [[ -n ${RDS_SNAPSHOT} ]]; then
    PARAMS+="~$(atl_param "DBSnapshotId" "${RDS_SNAPSHOT}")"
fi
if [[ -n ${EBS_SNAPSHOT} ]]; then
    PARAMS+="~$(atl_param "HomeVolumeSnapshotId" "${EBS_SNAPSHOT}")"
fi
if [[ -n ${STANDBY_DB_MASTER} ]]; then
    PARAMS+="~${STANDBY_DB_MASTER}"
fi
if [[ -n ${SSL_CERTIFICATE} ]]; then
    PARAMS+="~${SSL_CERTIFICATE}"
fi

${BASEDIR}/create-stack.sh "BitbucketDataCenter.template" "${PARAMS}"
