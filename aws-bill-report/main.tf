terraform {
  backend "s3" {
    bucket = "hanaldo-terraform"
    key    = "aws-bill-report"
    region = "ap-northeast-2"
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.51.1"
    }
  }
}

provider "aws" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create Lambda Function to get aws billing and send it to SLACK
module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"

  function_name = "aws-bill-report"
  description = "Function to get aws bill and send it to SLACK"
  handler = "main.lambda_handler"
  runtime = "python3.9"
  architectures = [ "arm64" ]
  publish = true

  source_path = "${path.module}/templates"

  environment_variables = {
    SLACK_BOT_TOKEN = var.slack_bot_token
    SLACK_CHANNEL = var.slack_channel
  }

  attach_policy_statements = true
  policy_statements = {
    cost_explorer_all = {
      effect    = "Allow",
      actions   = ["ce:*"],
      resources = ["*"]
    },
  }
}

module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  role_name = "aws-bill-report-function-invoke-role"
  attach_lambda_policy = true
  lambda_target_arns   = [ module.lambda.lambda_function_arn_static ]

  schedules = {
    invoke-lambda = {
      description = "Invoke aws-bill-report Lambda Function"
      schedule_expression = "cron(0 9 * * ? *)"
      timezone = "Asia/Seoul"
      arn = module.lambda.lambda_function_arn_static
    }
  }
}

# Set lambda permission after create lambda function and event bridge scheduler
resource "aws_lambda_permission" "allow_eventbridge_scheduler" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = module.eventbridge.eventbridge_schedule_arns["invoke-lambda"]
}