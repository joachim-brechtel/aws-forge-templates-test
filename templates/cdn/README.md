## Deploying a CloudFront CDN stack

You can use [Amazon CloudFront](https://aws.amazon.com/cloudfront/) as your Atlassian deployment's third-party Content Delivery Network (CDN). Specifically, you can provision a CloudFront stack to act as a CDN for your Jira or Confluence deployment.

This directory contains templates that help you provision and configure the right CloudFront stack for your deployment:

### CDN for public deployments

If your Atlassian deployment **is publicly accessible**, you can deploy a CloudFront CDN stack using the [AtlassianCDN.template.yaml](AtlassianCDN.template.yaml) template. This template will only require your Atlassian deployment's `Service URL`.

After deploying your CloudFront CDN stack, open its Stack Details page. From there, check the Outputs tab and note the value of `CDNDomainName`; this is your `CDN URL`. You'll need to configure your Atlassian deployment to use this URL.

**PLACEHOLDER: LINKS TO INSTRUCTIONS ([DRAFT](https://extranet.atlassian.com/display/CONFIX/How+to+configure+a+CDN+for+Confluence+Data+Center))**

> **IMPORTANT:** Your Atlassian deployment doesn't have to be hosted on AWS in order to use this template's CloudFront stack.

### CDN for private deployments

The [AtlassianCDNInternal.template.yaml](AtlassianCDNInternal.template.yaml) template deploys a CloudFront CDN for Atlassian deployments that are **hosted on AWS but not accessible publicly**. These are Jira or Confluence sites whose `Service URL`s are only accessible within private networks.

The [AtlassianCDNInternal.template.yaml](AtlassianCDNInternal.template.yaml) template requires the following parameters to do access your private deployment:

- `Service URL`: your deployments base URL.
- `EC2 instance serving assets`: any of the application nodes that the CDN can take assets from.
- `VPC`: the ID of your Atlassian deployment's VPC. If you used one of our AWS Quick Starts, this will be the ID of your [Atlassian Standard Infrastructure](https://aws.amazon.com/quickstart/architecture/atlassian-standard-infrastructure/) stack.
- `Public subnets`: a list of public subnets (in the VPC defined above) that the CloudFront's load balancer will associate with.
- `Security Group`: a new security group to be used by the new CloudFront stack's load balancer.

After deploying your CloudFront CDN stack, open its Stack Details page. From there, check the Outputs tab and note the value of `LoadBalancerURL`; this is your `CDN URL`. You'll need to configure your Atlassian deployment to use this URL.

**PLACEHOLDER: LINKS TO INSTRUCTIONS ([DRAFT](https://extranet.atlassian.com/display/CONFIX/How+to+configure+a+CDN+for+Confluence+Data+Center))**


> **IMPORTANT:**
> The [AtlassianCDNInternal.template.yaml](AtlassianCDNInternal.template.yaml) template can only deploy a CloudFront CDN for **private Atlassian deployments hosted on AWS**. This is because the CDN needs to connect directly to your deployment's VPC and one of its application nodes (both of which only be accessed within AWS).
>
> In addition,  we've only tested this template with private deployments created through our [Jira](https://aws.amazon.com/quickstart/architecture/jira/) and [Confluence](https://aws.amazon.com/quickstart/architecture/confluence/) Quick Starts. You may need to edit the [AtlassianCDNInternal.template.yaml](AtlassianCDNInternal.template.yaml) template accordingly if your deployment has additional connection requirements.
