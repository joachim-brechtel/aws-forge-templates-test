#### Lambda Cleaner

Helps clean up test AWS resources after `taskcat` runs on CI. Deletes cloudformation stacks created by taskcat as well as Route53 records
created for HTTPS taskcat deloyments. We usually use deplops.com hosted zone

#### Development

Install development packages

`pip install -r requirements`

Authenticate with `cloudtoken`

`. cloudtoken -r <role-id>`

To run the lambda using a REPL (python|ptpython)

`CLEANUP_AWS_ACCOUNT=xxx CLEANUP_AWS_REGION=us-east-2 CLEANUP_TASKCAT_ONLY=True DRY_RUN=True python`

Import the required function and eval

```
from cleanup import handler
handler(None, None)
```

#### Deployment

- Ensure `cloudtoken` has been called and a valid token is present.
- Run `aws configure` to ensure you are running the lambda from the desired region
- To create a lambda the first time, run

`make aws-account=account_id aws-role=role_id hosted-zone=hosted_zone_id create-lambda`

- To update existing lambda function run

`make update-lambda`

- To delete existing lambda function run

`make delete-lambda`


#### TODO

* Remove DB snapshots
* Remove S3 buckets
