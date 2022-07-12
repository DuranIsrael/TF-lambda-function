provider "aws" {
  region = "us-east-1"
}

data "archive_file" "lambda-zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-role"
  assume_role_policy = <<EOF
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
          }
        }
      }
    ]
    EOF
}


resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  function_name    = "lambda-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda-sip.output_base64sha256
  runtime          = "python3.8"
}

resource "aws_api_gateway_api" "apilambda" {
  name          = "myapi"
  protocol_type = "HTTP"
}

resource "aws_api_gateway_stage" "lambdastage" {
  api_id      = aws_api_gateway_api.apilambda.api_id
  name        = "$default"
  auto_deploy = true
}

resource "aws_api_gateway_integration" "lambda-integration" {
  api_id               = aws_api_gateway_api.apilambda.api_id
  integration_type     = "AWS_PROXY"
  integration_method   = "POST"
  integration_url      = aws_lambda_function.lambda.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_api_gateway_api.apilambda.api_id
  route_key = "GET /{proxy+}"
  target    = "integration/${aws_api_gateway_integration.lambda-integration.id}"

}

resource "aws_lambda_permission" "api-gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_api.apilambda.execution_arn}/*/*/*"
}