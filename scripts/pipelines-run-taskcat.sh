#!/usr/bin/env bash

case $PRODUCT in
    jira|bitbucket|confluence) echo "Running tasckat test for ${PRODUCT}"  ;;
    *) echo '$PRODUCT variable contains unexpected value:' ${PRODUCT} && exit 1 ;;
esac

# Identifier for the run (used for tagging AWS resources)
RUN_ID="tcat-${PRODUCT}-${BITBUCKET_BUILD_NUMBER}"

taskcat -n -c quickstarts/quickstart-atlassian-${PRODUCT}/ci/taskcat-ci.yml -t taskcat-ci-run=true -t taskcat-ci-run-id=${RUN_ID} -t override_periodic_cleanup=false
export STACK_NAME=$(aws cloudformation describe-stacks  | jq -c --arg build_tag_id "${RUN_ID}" '.Stacks | map( select( any(.Tags[]; .Key=="taskcat-ci-run-id" and .Value == $build_tag_id))) | .[0] | .StackName' | tr -d '"')
export SERVICE_URL=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" | jq -c '.Stacks | .[].Outputs | .[] | select(.OutputKey=="ServiceURL") | .OutputValue' | tr -d '"')
echo ${SERVICE_URL}

if [[ ${PRODUCT} == 'confluence' ]]; then
    export LOAD_BALANCER=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" | jq '.Stacks[0].Outputs'|jq '.[] | select(.OutputKey=="ConfluenceTargetGroupARN")|.OutputValue'|tr -d '"')
    aws elbv2 wait target-in-service --target-group-arn $LOAD_BALANCER
else
    export LOAD_BALANCER=$(aws cloudformation describe-stack-resources --stack-name "${STACK_NAME}" | jq -c '.StackResources | .[] | select(.LogicalResourceId=="LoadBalancer") | .PhysicalResourceId' | tr -d '"')
    aws elb wait any-instance-in-service --load-balancer-name $LOAD_BALANCER
fi

echo ${LOAD_BALANCER}
sleep 10
curl --fail ${SERVICE_URL}/status
