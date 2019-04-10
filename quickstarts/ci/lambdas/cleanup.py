import logging
import os
import re

import boto3
from distutils.util import strtobool
import datetime 
from dateutil import tz

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

# Debug only - Dry Run doesn't work for load balancers so we don't use AWS API DryRun parameter
# and just printing the instances that are designated for termination but don't kill them
DRY_RUN = os.getenv('DRY_RUN', False)
CLEANUP_TASKCAT_ONLY = strtobool(os.getenv('CLEANUP_TASKCAT_ONLY', 'True'))

RUN_ID_TAG='taskcat-ci-run-id'
CI_HOSTED_ZONE_ID='Z2R1NCP8IR4TFQ'

logger = logging.getLogger(__name__)
logging_level = logging.DEBUG
logger.setLevel(logging_level)


def configure_logging():
    logging.basicConfig(format='[%(levelname)s] %(message)s', level=logging_level)
    logging.getLogger('boto3').setLevel(logging.WARN)
    logging.getLogger('botocore').setLevel(logging.WARN)


def handler(_event, _context):
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
    stack_status_list = ['CREATE_COMPLETE', 'UPDATE_COMPLETE', 'ROLLBACK_COMPLETE', 'DELETE_FAILED']
    stack_summary_dict = cfn.list_stacks(StackStatusFilter=stack_status_list)
    filtered_stacks = stack_summary_dict['StackSummaries']
    root_stacks = [stack for stack in filtered_stacks if 'RootId' not in stack.keys()]
    [delete_cfn_stack_and_r53_record(cfn, stack) for stack in root_stacks if
     not should_retain_stack(cfn, stack['StackId'], CLEANUP_TASKCAT_ONLY)]
    return True


def should_retain_stack(cfn, stack_id: str, cleanup_taskcat_only: bool) -> bool:
    stack_description = cfn.describe_stacks(StackName=stack_id)
    stacks = stack_description['Stacks']
    if len(stacks) != 1:
        raise Exception('StackId has to be unique and must resolve to one stack')
    stack = stacks[0]
    tags = stack['Tags']
    logger.debug("Tags: %s", tags)

    override_cleanup_tag_set = next(
        (tag for tag in tags if tag['Key'] == 'override_periodic_cleanup' and strtobool(tag['Value'])),
        None) is not None

    if override_cleanup_tag_set:
        logger.info("Retaining stack with name : %s", stack['StackName'])
        return True

    logger.info("Has the stack been created by taskcat? : %s", stack['StackName'])
    return not (cleanup_taskcat_only and can_purge_stack(stack))


def can_purge_stack(stack: dict) -> bool:
    stack_last_updated_at = stack.get("LastUpdatedTime")
    stack_created_at = stack.get("CreationTime")

    stack_last_touched_timestamp = stack_last_updated_at if stack_last_updated_at is not None else stack_created_at

    now = datetime.datetime.now().replace(tzinfo=tz.tzutc())
    logger.info("Stack with name :%s last created more than 2 hour ago", stack["StackName"])
    is_stack_last_modified_more_than_1_hour_ago = round((now - stack_last_touched_timestamp).total_seconds()) > 7200

    return stack['StackName'].lower().startswith('tcat') and is_stack_last_modified_more_than_1_hour_ago 


def delete_cfn_stack_and_r53_record(cfn_client, stack: dict) -> None:
    logger.info("Cleaning up stack: %s", stack['StackName'])
    delete_taskcat_r53_record(cfn_client, stack['StackId'])
    delete_cfn_stack(cfn_client, stack)

def delete_cfn_stack(cfn_client, stack: dict) -> None:
    logger.info("Deleting stack :%s", stack['StackName'])
    if not DRY_RUN:
        try:
            delete_stack_resources(cfn_client, stack)
            cfn_client.delete_stack(StackName=stack['StackName'])
        except Exception as e:
            logger.error("Error deleting CFn stack: %s", stack['StackName'])
            logger.error(repr(e))


def delete_stack_resources(cfn_client, stack):
    if stack["StackStatus"] == "DELETE_FAILED":
        resource_list = cfn_client.describe_stack_resources(StackName=stack["StackName"])
        region_name = cfn_client._client_config.region_name
        for resource in resource_list:
            _build_aws_resource(resource, region_name).delete_resource()

def delete_taskcat_r53_record(cfn_client, stack_id: str) -> None:
    stack_description = cfn_client.describe_stacks(StackName=stack_id)
    stacks = stack_description['Stacks']
    if len(stacks) != 1:
        raise Exception('StackId has to be unique and must resolve to one stack')

    stack = stacks[0]
    tags = stack['Tags']
    logger.info("Deleting route53 record for stack: %s", stack['StackName'])

    run_id = [tag['Value'] for tag in tags if tag['Key'] == RUN_ID_TAG]
    if len(run_id) == 0:
        logger.error('no run ID found for cfn stack: %s', stack['StackName'])
    else:
        expr = re.compile('tcat-(.*)-([0-9]*)')
        match = expr.match(run_id[0])
        if len(match.groups()) != 2:
            logger.error('ill-formatted run ID () for cfn stack: %s', run_id[0], stack['StackName'])
        else:
            product = match.group(1)
            bamboo_build_no = match.group(2)
            r53 = boto3.client('route53')
            records = r53.list_resource_record_sets(HostedZoneId=CI_HOSTED_ZONE_ID)
            record_sets = records['ResourceRecordSets']
            matched_stack_records = [record for record in record_sets if record['Name'] == 'taskcat-bamboo-{}-{}.deplops.com.'.format(bamboo_build_no, product)]
            if len(matched_stack_records) != 1:
                logger.error('Could not find corresponding record in hosted zone: %s for stack: %s', CI_HOSTED_ZONE_ID, stack['StackName'])
            else:
                logger.info('Deleting r53 record: %s', matched_stack_records[0]['Name'])
                change_resource = { 'Action': 'DELETE', 'ResourceRecordSet': matched_stack_records[0] }
                if not DRY_RUN:
                    r53.change_resource_record_sets(
                        HostedZoneId=CI_HOSTED_ZONE_ID,
                        ChangeBatch={
                            'Comment': 'deleted by taskcat cleanup',
                            'Changes': [
                                change_resource
                            ]
                        }
                    )

client_dict = {}


def build_ec2_client(region: str):
    if "ec2" not in client_dict:
        ec2_client = boto3.client('ec2', region_name=region)
        client_dict["ec2"] = ec2_client
        return ec2_client
    return client_dict.get("ec2")


def build_asg_client(region: str):
    if "autoscaling" not in client_dict:
        ec2_client = boto3.client('autoscaling', region_name=region)
        client_dict["autoscaling"] = ec2_client
        return ec2_client
    return client_dict.get("autoscaling")


class AwsResource:
    def delete_resource(self):
        pass


class ClusterNodeGroup(AwsResource):
    def __init__(self, logical_id, physical_id, region):
        self.region = region
        self.logical_id = logical_id
        self.physical_id = physical_id

    def delete_resource(self):
        try:
            build_asg_client(region=self.region).delete_auto_scaling_group(AutoScalingGroupName=self.physical_id,
                                                                           Force=True)
        except Exception as e:
            logger.error("Exception while deleting ASG with ID - %s:%s", self.physical_id, self.logical_id)
            logger.error("Exception  %s", repr(e))


class SecurityGroup(AwsResource):
    def __init__(self, logical_id, physical_id, region):
        self.region = region
        self.logical_id = logical_id
        self.physical_id = physical_id

    def delete_resource(self):
        try:
            build_ec2_client(region=self.region).delete_security_group(GroupId=self.physical_id)
        except Exception as e:
            logger.error("Exception while deleting Security Group with ID - %s:%s", self.physical_id, self.logical_id)
            logger.error("Exception  %s", repr(e))


class NullAwsResource(AwsResource):
    def delete_resource(self):
        logger.info("No delete operation defined for unknown resource type")


def _build_aws_resource(resource: dict, region: str) -> AwsResource:
    logical_id = resource['LogicalResourceId']
    resource_type = resource["ResourceType"]
    physical_id = resource['PhysicalResourceId']

    if resource_type == "AWS::EC2::ClusterNodeGroup":
        return ClusterNodeGroup(logical_id, physical_id, region)
    if resource_type == "AWS::EC2::SecurityGroup":
        return SecurityGroup(logical_id, physical_id, region)
    return NullAwsResource()
