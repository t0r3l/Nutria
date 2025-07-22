# API Gateway
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name_prefix}-api"
  description = "API for Nutria nutrition optimization"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# API Gateway Resources
resource "aws_api_gateway_resource" "targets" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "targets"
}

resource "aws_api_gateway_resource" "optimize" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "optimize"
}

# Methods
resource "aws_api_gateway_method" "targets_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.targets.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "optimize_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.optimize.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integrations
resource "aws_api_gateway_integration" "targets_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.targets.id
  http_method = aws_api_gateway_method.targets_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.compute_targets.invoke_arn
}

resource "aws_api_gateway_integration" "optimize_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.optimize.id
  http_method = aws_api_gateway_method.optimize_post.http_method

  integration_http_method = "POST"
  type                   = "HTTP_PROXY"
  uri                    = "http://${aws_lb.main.dns_name}/optimize"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/json'"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compute_targets.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_integration.targets_lambda,
    aws_api_gateway_integration.optimize_proxy
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = local.common_tags
}