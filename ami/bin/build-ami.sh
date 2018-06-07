#!/bin/bash
set -e

TMP_DIR=$(mktemp -d -t atlaws)
trap "rm -rf ${TMP_DIR}" EXIT

BASEDIR=$(dirname $0)
source ${BASEDIR}/atl-aws-functions.sh

function usage {
    cat << EOF
usage: $0 options

This script generates an Atlassian AMI with Packer.

OPTIONS:
   -p The product to build an AMI for. If not supplied 'Bitbucket' is assumed
   -r The AWS region to use. If not supplied, the AWS_REGION environment variable must be set
   -v The AWS VPC to use in the supplied region. If not supplied, the AWS_VPC_ID environment variable must be set
   -s The AWS Subnet to use in the supplied VPC. If not supplied, the AWS_SUBNET_ID environment variable must be set
   -c Whether to copy the AMI to other AWS regions. Defaults to false
   -u Whether to update the CloudFormation templates\' AMI mappings. Defaults to false
EOF
}

function err_usage {
    echo "Error: $1"
    echo
    usage
    exit 1
}

export AWS_LINUX_VERSION="2017.09.1"
COPY_AMIS=
UPDATE_CLOUDFORMATION=
ATL_PRODUCT="Bitbucket"

while getopts "hr:cv:s:p:u" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         p)
             ATL_PRODUCT="${OPTARG}"
             ;;
         r)
             AWS_REGION="${OPTARG}"
             ;;
         s)
             AWS_SUBNET_ID="${OPTARG}"
             ;;
         c)
             COPY_AMIS=true
             ;;
         u)
             UPDATE_CLOUDFORMATION=true
             ;;
         v)
             AWS_VPC_ID="${OPTARG}"
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

ATL_PRODUCT_ID=$(echo "${ATL_PRODUCT}" | tr '[:upper:]' '[:lower:]')
case $ATL_PRODUCT_ID in
    bitbucket)
        ATL_PRODUCT="Bitbucket"
        ;;
    jira)
        ATL_PRODUCT="JIRA"
        ;;
    confluence)
        ATL_PRODUCT="Confluence"
        ;;
    *)
        echo "Unsupported product specified."
        exit 1

esac

AWS_REGION=$(echo "${AWS_REGION}" | tr [:upper:] [:lower:])
AWS_VPC_ID=$(echo "${AWS_VPC_ID}" | tr [:upper:] [:lower:])

if [[ -z "${AWS_REGION}" ]]; then
    err_usage "AWS region option not supplied (-r) nor defined as an env var (AWS_REGION)"
fi

if [[ -z "${AWS_VPC_ID}" ]]; then
    err_usage "AWS VPC option not supplied (-v) nor defined as an env var (AWS_VPC_ID)"
fi

if [[ -z "${AWS_SUBNET_ID}" ]]; then
    err_usage "AWS Subnet option not supplied (-s) nor defined as an env var (AWS_SUBNET_ID)"
fi

if [[ -z "${AWS_ACCESS_KEY:-$AWS_ACCESS_KEY_ID}" ]]; then
    err_usage "AWS_ACCESS_KEY and AWS_ACCESS_KEY_ID env var not defined"
fi

if [[ -z "${AWS_SECRET_KEY:-$AWS_SECRET_ACCESS_KEY}" ]]; then
    err_usage "AWS_SECRET_KEY and AWS_SECRET_ACCESS_KEY env var not defined"
fi

DEFAULT_BASE_AMI=$(atl_awsLinuxAmi "$AWS_REGION" "$AWS_LINUX_VERSION")
BASE_AMI="${BASE_AMI:-$DEFAULT_BASE_AMI}"
if [[ -z "${BASE_AMI}" ]]; then
    err_usage "BASE_AMI env var not defined and no mapping found to fall back on"
fi


export AWS_DEFAULT_REGION=${AWS_REGION}
export TZ=GMT
DATE=$(date '+%Y.%m.%d_%H%M')

echo "Building ${ATL_PRODUCT} in ${AWS_REGION}"

packer -machine-readable build \
  -var aws_access_key="${AWS_ACCESS_KEY}" \
  -var aws_secret_key="${AWS_SECRET_KEY}" \
  -var aws_session_token="${AWS_SESSION_TOKEN}" \
  -var vpc_id="${AWS_VPC_ID}" \
  -var base_ami="${BASE_AMI}" \
  -var subnet_id="${AWS_SUBNET_ID}" \
  -var "aws_region"="${AWS_REGION}" \
  -var "aws_linux_version"="${AWS_LINUX_VERSION}" \
  $(dirname $0)/../${ATL_PRODUCT_ID}.json | tee "${TMP_DIR}/packer.log"

AWS_AMI=$(grep "amazon-ebs: AMI:" "${TMP_DIR}/packer.log" | awk '{ print $4 }')

if [[ -z "${AWS_AMI}" ]]; then
    echo "Packer failed to build the AMI"
    exit 1
fi
echo "AMI created: ${AWS_AMI}"

echo "Tagging AMI ${AWS_AMI} with name \"Atlassian ${ATL_PRODUCT} (${DATE})\""
NAME_TAG="$(atl_createTag "Name" "Atlassian ${ATL_PRODUCT} ${DATE}")"

aws ec2 create-tags --resource "${AWS_AMI}" --tags "${NAME_TAG}"

declare -a regionToAmi
i=0
regionToAmi[$i]=$(atl_regionMapping "${AWS_REGION}" "${AWS_AMI}")

if [[ -n "${COPY_AMIS}" ]]; then
    AWS_AMI_NAME=$(aws ec2 describe-images --image-ids ${AWS_AMI} | jq -r ".Images[0].Name")
    AWS_REGIONS=$(aws ec2 describe-regions | jq -r ".Regions[].RegionName")
    AWS_OTHER_REGIONS=${AWS_REGIONS[@]/$AWS_REGION}
    echo "Copying AMI ${AWS_AMI} to regions ${AWS_OTHER_REGIONS}"
    for region in ${AWS_OTHER_REGIONS[@]}; do
        ami=$(aws ec2 copy-image --source-region "${AWS_REGION}" --source-image-id "${AWS_AMI}" --region "${region}" --name "${AWS_AMI_NAME}" | jq -r ".ImageId")
        (
            echo "Copy to ${region} started (AMI ID: ${ami})"
            aws ec2 create-tags --region "${region}" --resource "${ami}" --tags "${NAME_TAG}"
        )
        i=$((i+1))
        regionToAmi[$i]=$(atl_regionMapping "${region}" "${ami}")
    done
fi

if [[ -n "${UPDATE_CLOUDFORMATION}" ]]; then
    echo "Updating ${ATL_PRODUCT} CloudFormation template AMI mapping(s)..."
    TEMPLATES=$(find ${BASEDIR}/../../templates -iname "${ATL_PRODUCT}*.template" -maxdepth 1)
    MAPPING_JSON=$(IFS=,\n; echo "${regionToAmi[*]}")

    for template in ${TEMPLATES[@]}; do
        if [[ $(head -n 1 "${template}") == "---" ]]; then
            cat "${template}" | atl_replaceYAMLAmiMapping "${MAPPING_JSON}" > "${template}.tmp"
        else
            cat "${template}" | atl_replaceJSONAmiMapping "${MAPPING_JSON}" > "${template}.tmp"
        fi
        rm "${template}"
        mv "${template}.tmp" "${template}"
    done
fi
echo "Done"