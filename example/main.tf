# example 1
module "s3-notification" {
  source = "../"

  s3_bucket_name  = "your-bucket-name"
  lambda_arn      = "your-lambda-arn"
  events          = "s3:ObjectCreated:*"
  prefix          = "foo"
  suffix          = ".jpeg"
  notification_id = "image upload notification"
}

# example 2 - no prefix/suffix & multiple events & unique id example
module "s3-notification" {
  source = "../"

  s3_bucket_name  = "your-bucket-name2"
  lambda_arn      = "your-lambda-arn2"
  events          = "s3:ObjectCreated:Copy, s3:ObjectCreated:Put"         # multiple events
  notification_id = join("__", ["your-bucket-name2", "your-lambda-arn2"]) # a unique id
}
