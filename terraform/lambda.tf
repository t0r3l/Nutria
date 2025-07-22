# Ensure build directories exist
resource "null_resource" "create_dirs" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/../builds ${path.module}/../layers"
  }
}

# Lambda Layer for dependencies
resource "aws_lambda_layer_version" "targets_layer" {
  filename         = "${path.module}/../layers/targets_layer.zip"
  layer_name       = "${local.name_prefix}-targets-layer"
  source_code_hash = filebase64sha256("${path.module}/../layers/targets_layer.zip")

  compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11"]

  description = "Layer containing dependencies for compute targets Lambda"
  
  depends_on = [null_resource.create_dirs]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "compute_targets_logs" {
  name              = "/aws/lambda/${local.name_prefix}-compute-targets"
  retention_in_days = 7

  tags = local.common_tags
}

# Lambda Function
resource "aws_lambda_function" "compute_targets" {
  filename         = "${path.module}/../builds/targets_lambda.zip"
  function_name    = "${local.name_prefix}-compute-targets"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory
  source_code_hash = filebase64sha256("${path.module}/../builds/targets_lambda.zip")

  layers = [aws_lambda_layer_version.targets_layer.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.compute_targets_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  tags = local.common_tags
}