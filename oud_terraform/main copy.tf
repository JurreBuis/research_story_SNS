provider "aws" {}

# zip lambda functions
data "archive_file" "zip_sns_test_lambda" {
  type        = "zip"
  output_path = "lambda/zips/lambda_function_sns.zip"
  source_dir  = "lambda/lambda_function_sns"
}

data "archive_file" "zip_datetime_lambda" {
  type        = "zip"
  output_path = "lambda/zips/lambda_function_datetime.zip"
  source_dir  = "lambda/lambda_function"
}


# setup SQS
resource "aws_sqs_queue" "demo_queue" {
  name = "demo_queue"
  
  visibility_timeout_seconds  = 30
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  message_retention_seconds   = 84600
  max_message_size            = 262144
}

# allow SNS to use the SQS queue
resource "aws_sqs_queue_policy" "allow-sns-to-sqs" {
  queue_url = aws_sqs_queue.demo_queue.id
  policy    = jsonencode({
    Version = "2012_10_17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = "${aws_sqs_queue.demo_queue.arn}"
        Condition = {
          ArnEquals = {
            "aws:SourceArn": "${aws_sns_topic.demo_topic.arn}"
          }
        }
      }
    ]
  })
}

# setup Lambda function 1 sns message test (SNS -> SQS -> Lambda)
resource "aws_lambda_function" "sns_test_function" {
  depends_on = [
    data.archive_file.zip_sns_test_lambda,
    aws_sqs_queue.demo_queue
  ]

  role          = aws_iam_role.iam_demo.arn
  filename      = "lambda/zips/lambda_function_sns.zip"
  function_name = "sns_message"
  runtime       = "python3.9"
  handler       = "sns_test_function.lambda_handler"
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_mapping" {
  event_source_arn = aws_sqs_queue.demo_queue.arn
  function_name    = aws_lambda_function.sns_test_function.arn
}

# setup Lambda function 2; Datetime (SNS -> Lambda)
resource "aws_lambda_function" "datetime_lambda" {
  depends_on = [
    data.archive_file.zip_datetime_lambda,
  ]

  role          = aws_iam_role.iam_demo.arn
  filename      = "lambda/zips/lambda_function_datetime.zip"
  function_name = "datetime_print"
  runtime       = "python3.9"
  handler       = "current_datetime_lambda.lambda_handler"
}


# SNS
resource "aws_sns_topic" "demo_topic" {
  name = "demo_topic"
}

# e-mail subscription to SNS topic
resource "aws_sns_topic_subscription" "email_topic_sub" {
  topic_arn = aws_sns_topic.demo_topic.arn
  protocol  = "email"
  endpoint  = "jfjbuis@gmail.com"

  filter_policy = jsonencode({
    e_mail = ["true"]
  })
}

# SQS subscription to SNS topic
resource "aws_sns_topic_subscription" "sqs_topic_sub" {
  depends_on = [
    aws_sns_topic.demo_topic,
    aws_sqs_queue.demo_queue
  ]

  topic_arn = aws_sns_topic.demo_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.demo_queue.arn
  raw_message_delivery = false

  filter_policy = jsonencode({
    LambdaSQS = ["true"]
  })
}

# Lambda subscription to SNS topic
resource "aws_sns_topic_subscription" "lambda_topic_sub" {
  depends_on = [
    aws_sns_topic.demo_topic,
    aws_lambda_function.datetime_lambda
  ]
  topic_arn = aws_sns_topic.demo_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.datetime_lambda.arn

  filter_policy = jsonencode({
    LambdaSQS = ["true"]
  })
}

resource "aws_lambda_permission" "with_sns" {
  statement_id = "allow_execution_from_sns"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.datetime_lambda.arn}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.demo_topic.arn}"
}


# iam execution role and policies
resource "aws_iam_role" "iam_demo" {
  name = "iam_demo"
  assume_role_policy = jsonencode({
    Version = "2012_10_17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
#   role       = aws_iam_role.iam_demo.name
#   policy_arn = "arn:aws:iam::aws:policy/service_role/AWSLambdaBasicExecutionRole"
# }

resource "aws_iam_role_policy_attachment" "sqs_full_acces" {
  role       = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/service_role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full_access" {
  role       = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

