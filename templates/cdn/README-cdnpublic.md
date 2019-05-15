## CloudFront CDN for public deployments

If your Atlassian deployment **is publicly accessible**, you can deploy a CloudFront CDN stack using the [AtlassianCDN.template.yaml](AtlassianCDN.template.yaml) template. This template will only require your Atlassian deployment's `Service URL`.

After deploying your CloudFront CDN stack, open its Stack Details page. From there, check the Outputs tab and note the value of `CDNDomainName`; this is your `CDN URL`. You'll need to configure your Atlassian deployment to use this URL.

**PLACEHOLDER: LINKS TO INSTRUCTIONS ([DRAFT](https://extranet.atlassian.com/display/CONFIX/How+to+configure+a+CDN+for+Confluence+Data+Center))**

**IMPORTANT:** Your Atlassian deployment doesn't have to be hosted on AWS in order to use this template's CloudFront stack.
