# HOWTO Clone a Quickstart to the AWS upstream repos

## Background

The quickstarts under [quickstarts/](quickstarts/) are double as the quickstarts
[we offer to our customers](https://aws.amazon.com/quickstart/architecture/jira/).
Periodically we push cumulative changes up to the quickstart repositories hosted
by AWS on Github. These repositories are then published on the [AWS quickstart
site](https://aws.amazon.com/quickstart/).

## Target Repositories

There are 3 upstream product repositories we support:

* [Jira Quickstart][quickstart-atlassian-jira]
* [Confluence Quickstart][quickstart-atlassian-confluence]
* [Bitbucket Quickstart][quickstart-atlassian-bitbucket]

Additionally, there is a supporting quickstart; [Atlassian Services][quickstart-atlassian-services].
This is the common VPC to support multiple services with intercommunication, and
includes a bastion host.

## Repository structure

Each repository contains 2 related quickstart templates; the main product
installation template (e.g. [Bitbucket](https://github.com/aws-quickstart/quickstart-atlassian-bitbucket/blob/develop/templates/quickstart-bitbucket-dc.template.yaml)),
which expects to be installed into an existing VPC called `ATL-VPCID`. The
second template wraps this, calling the [Atlassian Services][quickstart-atlassian-services]
template to setup the VPC before calling the product template. These templates
are placed under [templates/](templates/).

Ideally, the product-only template should be a 1-to-1 copy of the corresponding
template from this repository, e.g. _FIXME: Insert Jira example after merge._
Any adjustments should be made via the wrapping meta-template.

There are two main branches; `master`, which is effectively production, and
`develop` for work pending merge. Additionally, PRs are prepared on a fork of
the repository (see below).

### Fork and directory structure

Currently there are effectively 3 repositories in play for each template:

* This Bitbucket one: the source of truth for our quickstart and internal templates.
* The upstream AWS Github repository, e.g. [quickstart-atlassian-jira].
* An intermediate fork hosted under the Atlassian Github organisation; e.g.
  [atlassian/quickstart-atlassian-jira](https://github.com/atlassian/quickstart-atlassian-jira).

In practice, the templates are _copied_ from BB to the _develop_ branch of the
_Atlassian fork_. From there we create a _pull-request_ to the _AWS repository
develop branch_. Once the PR is merged CI will run, and on pass _develop_ will
be merged to _master_ and pushed to S3 and the AWS quickstart pages.

### Continuous Integration

The upstream repositories use [taskcat] to test deployment of the templates;
changes will not be accepted to master until these are passing. The taskcat main
file is [ci/taskcat.yml](ci/taskcat.yml). You should run taskcat against any
changes you make before attempting to push upstream.




[quickstart-atlassian-services]: https://github.com/aws-quickstart/quickstart-atlassian-services
[quickstart-atlassian-bitbucket]: https://github.com/aws-quickstart/quickstart-atlassian-bitbucket
[quickstart-atlassian-jira]: https://github.com/aws-quickstart/quickstart-atlassian-jira
[quickstart-atlassian-confluence]: https://github.com/aws-quickstart/quickstart-atlassian-confluence
[taskcat]: https://github.com/aws-quickstart/taskcat
