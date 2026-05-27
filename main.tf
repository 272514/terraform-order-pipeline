terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket       = "my-bucket-272514"
    key          = "order-pipeline/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "archive" {}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_s3_bucket" "orders" {
  bucket        = "so-survey-orders-bucket-xyz"
  force_destroy = true
}

resource "aws_sqs_queue" "orders_queue" {
  name                      = "order-processing-queue"
  message_retention_seconds = 86400
}

resource "aws_sns_topic" "order_notifications" {
  name = "order-notifications-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "email"
  endpoint  = "twój_email@example.com"
}

module "order_ingest" {
  source        = "./modules/lambda_function"
  function_name = "order-ingest"
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  role_arn      = data.aws_iam_role.lab_role.arn
  source_dir    = "${path.module}/functions/order_ingest"
  
  environment_vars = {
    ORDER_BUCKET    = aws_s3_bucket.orders.id
    ORDER_QUEUE_URL = aws_sqs_queue.orders_queue.url
  }
}

module "order_validator" {
  source        = "./modules/lambda_function"
  function_name = "order-validator"
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  role_arn      = data.aws_iam_role.lab_role.arn
  source_dir    = "${path.module}/functions/order_validator"

  environment_vars = {
    SECRET_PARAMETER_NAME = aws_ssm_parameter.api_secret_key.name
  }
}

module "order_processor" {
  source        = "./modules/lambda_function"
  function_name = "order-processor"
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  role_arn      = data.aws_iam_role.lab_role.arn
  source_dir    = "${path.module}/functions/order_processor"

  environment_vars = {
    ORDER_BUCKET  = aws_s3_bucket.orders.id
    SNS_TOPIC_ARN = aws_sns_topic.order_notifications.arn
  }
}
resource "aws_sfn_state_machine" "order_pipeline" {
  name     = "order-processing-state-machine"
  role_arn = data.aws_iam_role.lab_role.arn

  definition = jsonencode({
    Comment = "Order Processing Pipeline from Task 1"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = module.order_validator.function_arn
        Next     = "ProcessOrder"
      }
      ProcessOrder = {
        Type     = "Task"
        Resource = module.order_processor.function_arn
        End      = true
      }
    }
  })
}

resource "aws_api_gateway_rest_api" "order_api" {
  name        = "OrderProcessingAPI"
  description = "API Gateway for serverless order pipeline"
}

resource "aws_api_gateway_resource" "orders_resource" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_rest_api.order_api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "post_order" {
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.order_api.id
  resource_id             = aws_api_gateway_resource.orders_resource.id
  http_method             = aws_api_gateway_method.post_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${module.order_ingest.function_arn}/invocations"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  stage_name  = "prod"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.order_ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.order_api.execution_arn}/*/*"
}

resource "aws_ssm_parameter" "api_secret_key" {
  name        = "/order_pipeline/api_secret_key"
  description = "Poufny klucz API do autoryzacji zamowien"
  type        = "SecureString"
  value       = "SuperTajnyKluczZabezpieczajacy123!"
}