# Atlassian AWS CloudFormation QuickStart templates

The AWS QuickStart templates can all be found at the GitHub locations below:

 * [quickstart-atlassian-jira](https://github.com/atlassian/quickstart-atlassian-jira)
 * [quickstart-atlassian-confluence](https://github.com/atlassian/quickstart-atlassian-confluence)
 * [quickstart-atlassian-bitbucket](https://github.com/atlassian/quickstart-atlassian-bitbucket)
 * [quickstart-atlassian-services](https://github.com/atlassian/quickstart-atlassian-services)

# Atlassian AWS CloudFormation supplementary templates

This directory contains the following AWS CloudFormation Quickstart templates:

| Template Name | Purpose |
|---------------|-------------|
| `quickstart-backmac-for-atlassian-services.yaml` | This quickstart spins up Backmac in a pre-existing Atlassian Service VPC only
| `quickstart-forge-for-atlassian-services.yaml`   | This quickstart spins up Forge in a pre-existing Atlassian Service VPC only

**Key Terms:**

| Term | Definition |
|------|------------|
| `backmac` | [Backmac](https://community.atlassian.com/t5/Data-Center-articles/Introducing-Atlassian-CloudFormation-Backup-Machine/ba-p/881556#M25) is the backup machine toolset for automating the backup of atlassian product Cloudformation stacks and is required for stack replication and DR to alternate regions |
| `forge` | [Forge](https://community.atlassian.com/t5/Data-Center-articles/Introducing-Atlassian-CloudFormation-Forge/ba-p/881551) is a CloudFormation automation tool, which consolidates and simplifies most of the tasks you would need to do on Atlassian products in AWS in a single webUI  |

