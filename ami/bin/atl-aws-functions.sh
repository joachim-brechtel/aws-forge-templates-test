
function atl_createTag {
    local KEY=$1
    local VALUE=$2

    echo Key="${KEY}",Value="\"${VALUE}\""
}

function atl_toSentenceCase {
    echo "$(tr '[:lower:]' '[:upper:]' <<< ${1:0:1})${1:1}"
}

function atl_awsLinuxAmi {
    local REGION=${1:?"A region must be specified"}
    aws --region "${REGION}" ec2 describe-images \
        --owners 137112412989 \
        --filters Name=virtualization-type,Values=hvm Name=description,Values="Amazon Linux AMI 2016.09*HVM GP2" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text
}

function atl_regionMapping {
    local REGION=${1:?"A region must be specified"}
    local AMI_ID=${2:?"A AMI ID must be specified"}
    echo "\"${REGION}\": {\"HVM64\": \"${AMI_ID}\", \"HVMG2\": \"NOT_SUPPORTED\" }"
}

function atl_replaceJSONAmiMapping {
    local MAPPING_JSON=${1:?"A mapping must be specified"}
    jq ".Mappings.AWSRegionArch2AMI = { ${MAPPING_JSON} }"
}

function atl_replaceYAMLAmiMapping {
    local MAPPING_JSON=${1:?"A mapping must be specified"}
    local MAPPING_YAML=$(echo "{${MAPPING_JSON}}" | python -c 'import sys, yaml, json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' | sed 's/^/    /')
    perl -0777 -pe "s/AWSRegionArch2AMI:((  .*|\n)*)/AWSRegionArch2AMI:\n${MAPPING_YAML}\n/g"
}
