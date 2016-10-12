## Atlassian AWS CloudFormation templates

This directory contains the following AWS CloudFormation templates:

| Template Name | Description | File Server | Database | Proxy | Documentation |
|---------------|-------------|-------------|----------|-------|---------------|
| `BitbucketServer.template` | Template to spin up Bitbucket Server as a standalone instance with onboard proxy and database. | None | PostgreSQL (onboard) | Nginx (onboard) | [Documentation](https://confluence.atlassian.com/x/wZZKLg) 
| `BitbucketDataCenter.template` | Bitbucket Data Center template | EC2 & EBS based NFS Server | RDS PostgreSQL | ELB | - |
| `JiraDataCenter.template` | JIRA Data Center template | Elastic File System | RDS PostgreSQL | ELB | - |

To use, go to [the AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home?region=us-east-1) and click "Create New Stack"
and follow the prompts. 

You can also validate the template from the command line with the AWS Command Line Interface (CLI)
tools. See [the AWS documentation](http://docs.aws.amazon.com/cli/latest/userguide/installing.html).

Alternatively, you can use the `test<TemplateName>.sh` scripts in `/test` to: 

- Create your AWS Key Pair
- Create a VPC, subnets and an Internet Gateway
- Create the CloudFormation stack for the specified template

_Note:_ the CLI and test scripts require an access token to be available in your environment.
