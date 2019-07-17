## Deploying a CloudFront CDN stack

You can use [Amazon CloudFront](https://aws.amazon.com/cloudfront/) as your Atlassian deployment's third-party Content Delivery Network (CDN). Specifically, you can provision a CloudFront stack to act as a CDN for your Atlassian deployment.

This directory contains templates that help you provision and configure the right CloudFront stack for your deployment:

| Template | Description |
|----------|-------------|
| [AtlassianCDN.template.yaml](AtlassianCDN.template.yaml) | Provisions a CloudFront CDN stack for a [publicly-accessible Atlassian deployment](README-cdnpublic.md). Your Atlassian deployment doesn't need to be hosted on AWS. |
| [AtlassianCDNInternal.template.yaml](AtlassianCDNInternal.template.yaml) | Provisions a CloudFront CDN stack for [private Atlassian deployments hosted on AWS](README-cdnprivate.md). This template was designed specifically for private deployments created through our [Jira](https://aws.amazon.com/quickstart/architecture/jira/) and [Confluence](https://aws.amazon.com/quickstart/architecture/confluence/) Quick Starts. |
