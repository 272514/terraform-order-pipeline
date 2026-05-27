# Terraform sam generuje wirtualny plik z kodem w pamięci RAM i pakuje go do ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/../../files/${var.function_name}.zip"

  source {
    content  = <<EOF
def lambda_handler(event, context):
    print("Wywolano funkcje: ${var.function_name}")
    return {
        "statusCode": 200, 
        "body": "Hello from stable ${var.function_name} built by Terraform!"
    }
EOF
    filename = "handler.py"
  }
}

# Definicja funkcji Lambda z uzyciem powyzszego ZIP-a
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  handler          = var.handler
  runtime          = var.runtime
  role             = var.role_arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  dynamic "environment" {
    for_each = length(var.environment_vars) > 0 ? [1] : []
    content {
      variables = var.environment_vars
    }
  }
}

# Logi CloudWatch dla Lambdy
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7
}