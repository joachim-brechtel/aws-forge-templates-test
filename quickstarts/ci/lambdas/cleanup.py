import logging
import os
from datetime import datetime

import boto3
from dateutil import parser
from time import sleep

import pytz

""" Function to clean up resources created by Instant Environments
This function assumes that each resource that should be managed by the cleanup script requires
`delete_after` tag which contains datetime (in ISO 8601 format). 
"""

"""
Based on `https://stash.atlassian.com/projects/AV/repos/instenv-app/browse/utils/cleanup`
"""

# Environmental variables to configure the lambda function
AWS_REGIONS = os.getenv('CLEANUP_AWS_REGION')
AWS_ACCOUNT = os.getenv('CLEANUP_AWS_ACCOUNT')
DELETE_AFTER_TAG_KEY = os.getenv('CLEANUP_TAG', 'delete_after')

# Debug only - Dry Run doesn't work for load balancers so we don't use AWS API DryRun parameter
# and just printing the instances that are designated for termination but don't kill them
DRY_RUN = os.getenv('DRY_RUN', False)
CLEANUP_TASKCAT_ONLY = os.getenv('CLEANUP_TASKCAT_ONLY', 'True')

logger = logging.getLogger(__name__)
logging_level = logging.DEBUG
logger.setLevel(logging_level)

def configure_logging():
    logging.basicConfig(format='[%(levelname)s] %(message)s', level=logging_level)
    logging.getLogger('boto3').setLevel(logging.WARN)
    logging.getLogger('botocore').setLevel(logging.WARN)

def handler(event, context):
    print("Beginning Lambda from print")
    configure_logging()
    if not AWS_ACCOUNT or not AWS_REGIONS:
        logger.error("You need to setup AWS_ACCOUNT and AWS_REGIONS environment variables. See README.md")
        exit(1)

    regions = AWS_REGIONS.split(",")
    logger.info("regions: %s", regions)
    for region in regions:
        delete_cfn_stacks(region)

def delete_cfn_stacks(region: str) -> bool:
    cfn = boto3.client('cloudformation', region_name=region)
    stack_summary_dict = cfn.list_stacks(StackStatusFilter=['CREATE_COMPLETE','UPDATE_COMPLETE','ROLLBACK_COMPLETE'])
    filtered_stacks = stack_summary_dict['StackSummaries']
    root_stacks = [stack for stack in filtered_stacks if 'RootId' not in stack.keys()]
    [delete_cfn_stack(cfn, stack) for stack in root_stacks if not should_retain_stack(cfn, stack['StackId'], CLEANUP_TASKCAT_ONLY == 'True')]
    return True

def should_retain_stack(cfn, stackId: str , cleanup_taskcat_only: bool) -> bool:
    stack_description = cfn.describe_stacks(StackName=stackId)
    stacks = stack_description['Stacks']
    if len(stacks) != 1:
        raise Exception('StackId has to be unique and must resolve to one stack')
    stack = stacks[0]
    tags = stack['Tags']
    logger.debug("Tags: %s", tags)
    override_cleanup_tag_set = next((tag for tag in tags if tag['Key'] == 'override_periodic_cleanup' and tag['Value'].lower() == 'true'),None) != None
    if cleanup_taskcat_only:
        return stack['StackName'].lower().startswith('tcat') and not override_cleanup_tag_set
    return override_cleanup_tag_set

def delete_cfn_stack(cfn_client, stack: dict) -> None:
    logger.info("Deleting stack :%s", stack['StackName'])
    try:
        cfn_client.delete_stack(StackName=stack['StackName']) 
    except Exception as e:
        logger.error("Error deleting CFn stack: %s", stack['StackName'])
        logger.error(repr(e))
