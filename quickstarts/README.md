## Atlassian AWS CloudFormation Quickstart templates

This directory contains the following AWS CloudFormation Quickstart templates:

| Template Name | Purpose |
|---------------|-------------|
| `quickstart-backmac-for-atlassian-services.yaml` | This quickstart spins up Backmac in a pre-existing Atlassian Service VPC only
| `quickstart-crowd-master.template.yaml`          | This quickstart spins up a Crowd instance in a pre-existing Atlassian Service VPC only
| `quickstart-forge-for-atlassian-services.yaml`   | This quickstart spins up Forge in a pre-existing Atlassian Service VPC only

### Directory structure

> Directory structure changes are now complete.

The following quickstart templates have been moved to the [Atlassian org on GitHub](https://github.com/atlassian/) and are referenced from this repository as a `git submodule`:

  * [quickstart-atlassian-jira](https://github.com/atlassian/quickstart-atlassian-jira)
    - This quickstart spins up a Jira instance in either a pre-existing Atlassian Service VPC only or a new [Atlassian Standard Infrastructure stack](https://github.com/atlassian/quickstart-atlassian-services)
  * [quickstart-atlassian-confluence](https://github.com/atlassian/quickstart-atlassian-confluence)
      - This quickstart spins up a Confluence instance in either a pre-existing Atlassian Service VPC only or a new [Atlassian Standard Infrastructure stack](https://github.com/atlassian/quickstart-atlassian-services)
  * [quickstart-atlassian-bitbucket](https://github.com/atlassian/quickstart-atlassian-bitbucket)
      - This quickstart spins up a Bitbucket instance in either a pre-existing Atlassian Service VPC only or a new [Atlassian Standard Infrastructure stack](https://github.com/atlassian/quickstart-atlassian-services)
  * [quickstart-atlassian-services](https://github.com/atlassian/quickstart-atlassian-services) 
    - Provisions a [Bastion stack](https://github.com/atlassian/quickstart-atlassian-services/blob/master/quickstarts/quickstart-bastion-for-atlassian-services.yaml)
    - Provisions a VPC stack

The submodules refer to quickstart projects in the `develop` branch of the respective repo in the [Atlassian org on GitHub](https://github.com/atlassian/).

##### Development

- To make changes to the Bitbucket, Confluence, Jira or Atlassian Services templates, please raise a PR in the respective GitHub repository listed above.
- Once the changes have been accepted and merged into upstream develop, please synchronize the git submodules in this repository. 

**Key Terms:**

| Term | Definition |
|------|------------|
| `backmac` | [Backmac](https://community.atlassian.com/t5/Data-Center-articles/Introducing-Atlassian-CloudFormation-Backup-Machine/ba-p/881556#M25) is the backup machine toolset for automating the backup of atlassian product Cloudformation stacks and is required for stack replication and DR to alternate regions |
| `bastion` | An ec2 node with sshd and a public IP that allows you to connect to other resources inside the Atlassian Services VPC. |
| `forge` | [Forge](https://community.atlassian.com/t5/Data-Center-articles/Introducing-Atlassian-CloudFormation-Forge/ba-p/881551) is a CloudFormation automation tool, which consolidates and simplifies most of the tasks you would need to do on Atlassian products in AWS in a single webUI  |

### Use

Note: You must create `quickstart-for-atlassian-services` first as they create the network structure required by the other Quickstarts. 
> Alternately, run any of the quickstart-atlassian-<PRODUCT>-with-vpc templates (See Github repository links) to run any of the product specific templates that will create the standard set of services required for quickstarts to run.  

To use, go to [the AWS EC2 console - Key Pairs](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs:sort=keyName) 

* Switch to the region in which you will deploy your quickstart(s)
* Create your AWS Key Pair.

Go to [the AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home?region=us-east-1)

* Click "Create New Stack".
* Click "Choose file" and select the Quickstart you want to deploy.
* Follow the prompts.

