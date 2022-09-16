# s3_bucket_notification_lambda

Note: This is forked from [s3_bucket_notification_lambda](https://github.com/evalmee/s3_bucket_notification_lambda) by @evalmee. However, their code requires Ruby, which was a limiting factor for my team's setup, so I have reimplemented it with shellscripting.

A module to create a S3 notification to a lambda function.

The [module provided by AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) manage S3 notifications as one resource and only support a single notification configuration. (See issue https://github.com/hashicorp/terraform-provider-aws/issues/501)

With this module, you can manage your S3 notifications from different terraform stacks.

⚠️ **Limitation Warnings:** 
- This module only supports S3 notifications to a lambda function.
- The `notification_id` field is what is used for creation/updating/destruction. Any existing ids with the same value will be manipulated.
- The script works by using the `aws s3api put-bucket-notification-configuration` command from the AWScli, and is not reliable in parallel situations! Therefore, when applying/destroying, use the flag `--parallelism=1` for sequential executions (i.e. `terraform apply --parallelism=1` and `terraform destroy --paralleslism=1`). I am not sure how to fix this, so any ideas welcome :)
- As per the AWScli, multiple notifications in the same bucket with overlapping prefixes/suffixes may not be created as expected. This is the reason Hashicorp haven't implement this yet as they are unsure on the behaviour they should use. So, if using this code, make sure there is no overlap (and if not sure, see what notifications are created using the `get` command shown in the example below).
- This module is in alpha state and is not recommended for production.

Hopefully Hashicorp will fix this problem in the official aws provider resource in the near future.

## Example

```hcl
module "s3-notification" {
  source = "github.com/walter9388/s3_bucket_notification_lambda"

  s3_bucket_name = "your-bucket-name"
  lambda_arn = "your-lambda-arn"
  events = "s3:ObjectCreated:*"
  prefix = "foo"
  suffix = ".jpeg"
  notification_id = "image upload notification" # this must be unique, and is what is used for creation/updating/destruction
}
```

#### Using a bash shell directly
Make sure you give your shell executeable permissions (`chmod +x ./update_s3_notification.sh`).

Get all notifications in a bucket:
```bash
./update_s3_notification.sh --bucket <your-bucket-name> get
```

Create/Update notification (note events should be a comma seperated string without square brackets):
```bash
./update_s3_notification.sh --bucket <your-bucket-name> --lambda-arn <your-lamda-function-arn> --events <your-events> --prefix <prefix(optional)> --suffix <suffix(optional)> --id <your-notification-id> update
```

Delete notification from a bucket by id:
```bash
./update_s3_notification.sh --bucket <your-bucket-name> --id <your-notification-id> delete
```

Delete all notifications in a bucket (NOT advised!!!!):
```bash
./update_s3_notification.sh --bucket <your-bucket-name> deleteAll
```

Note: remember to set your `AWS_PROFILE` correctly before use (i.e. `export AWS_PROFILE=my-profile-name`).

## Requirements
- Linux (including the `AWScli` and `jq` libraries)