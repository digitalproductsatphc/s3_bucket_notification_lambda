locals {
  notification_id = var.notification_id
  bucket          = var.s3_bucket_name
  lambda_arn      = var.lambda_arn
  events          = var.events
  prefix          = var.prefix
  suffix          = var.suffix
}

data "aws_region" "current" {}

resource "null_resource" "s3_object_created_subscription" {
  triggers = {
    prefix          = local.prefix
    suffix          = local.suffix
    events          = local.events
    lambda_arn      = local.lambda_arn
    notification_id = local.notification_id
    bucket          = local.bucket
    aws_region = data.aws_region.current.name
  }

  provisioner "local-exec" {
    command     = "./update_s3_notification.sh --bucket '${self.triggers.bucket}' --lambda-arn '${self.triggers.lambda_arn}' --events '${self.triggers.events}' --prefix '${self.triggers.prefix}' --suffix '${self.triggers.suffix}' --id '${self.triggers.notification_id}' update"
    working_dir = path.module
    environment = {
      "AWS_REGION" = self.triggers.aws_region
    }
  }

  provisioner "local-exec" {
    when = destroy
    command     = "./update_s3_notification.sh --bucket '${self.triggers.bucket}' --lambda-arn '${self.triggers.lambda_arn}' --events '${self.triggers.events}' --prefix '${self.triggers.prefix}' --suffix '${self.triggers.suffix}' --id '${self.triggers.notification_id}' delete"
    working_dir = path.module
    environment = {
      "AWS_REGION" = self.triggers.aws_region
    }
  }
}
