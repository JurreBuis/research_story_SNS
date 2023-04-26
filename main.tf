provider "aws" {}

# zip lambda function
data "archive_file" "zip_sns_test_lambda" {
  type        = "zip"
  output_path = "lambda/zips/lambda_function_sns.zip"
  source_dir  = "lambda/lambda_function_sns"
}

data "archive_file" "zip_datetime_test_lambda" {
  type        = "zip"
  output_path = "lambda/zips/lambda_function_datetime.zip"
  source_dir  = "lambda/lambda_function_datetime"
}

# setup SQS
resource "aws_sqs_queue" "queue_demo" {
  name = "queue_demo"
  
  visibility_timeout_seconds  = 30
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  message_retention_seconds   = 84600
  max_message_size            = 262144
}

# allow SNS to use the SQS queue
resource "aws_sqs_queue_policy" "allow_sns_to_sqs" {
  queue_url = aws_sqs_queue.queue_demo.id
  policy    = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = "${aws_sqs_queue.queue_demo.arn}"
        Condition = {
          ArnEquals = {
            "aws:SourceArn": "${aws_sns_topic.demo_topic.arn}"
          }
        }
      }
    ]
  })
}

# setup Lambda function 1; sns message test (SNS -> SQS -> Lambda)
resource "aws_lambda_function" "sns_lambda_function" {
  depends_on = [
    data.archive_file.zip_sns_test_lambda
  ]

  role          = aws_iam_role.iam_demo.arn
  filename      = "lambda/zips/lambda_function_sns.zip"
  function_name = "sns_message"
  runtime       = "python3.9"
  handler       = "sns_test_function.lambda_handler"
}

resource "aws_lambda_event_source_mapping" "sqs_lambda_mapping" {
  event_source_arn = aws_sqs_queue.queue_demo.arn
  function_name    = aws_lambda_function.sns_lambda_function.arn
}

# setup Lambda function 2; Datetime (SNS -> Lambda)
resource "aws_lambda_function" "datetime_lambda" {
  depends_on = [
    data.archive_file.zip_sns_test_lambda,
  ]

  role          = aws_iam_role.iam_demo.arn
  filename      = "lambda/zips/lambda_function_datetime.zip"
  function_name = "current_datetime"
  runtime       = "python3.9"
  handler       = "current_datetime_lambda.lambda_handler"
}

resource "aws_lambda_permission" "sns_lambda_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.datetime_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.demo_topic.arn
}


# SNS
resource "aws_sns_topic" "demo_topic" {
  name = "demo_topic"
}

# e-mail subscription to SNS topic
resource "aws_sns_topic_subscription" "email_topic_sub" {
  topic_arn = aws_sns_topic.demo_topic.arn
  protocol  = "email"
  endpoint  = "your@email.com"

  filter_policy = jsonencode({
    e-mail = ["true"]
  })
}

# SQS subscription to SNS topic
resource "aws_sns_topic_subscription" "sqs_topic_sub" {
  depends_on = [
    aws_sns_topic.demo_topic,
    aws_sqs_queue.queue_demo
  ]

  topic_arn = aws_sns_topic.demo_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue_demo.arn
  # raw_message_delivery = false

  filter_policy = jsonencode({
    LambdaSQS = ["true"]
  })
}

# Lambda subscription to SNS topic
resource "aws_sns_topic_subscription" "lambda-topic-sub" {
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

# iam execution role and policies
resource "aws_iam_role" "iam_demo" {
  name = "iam_demo"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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


resource "aws_iam_role_policy_attachment" "sqs_full_acces" {
  role       = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full_access" {
  role       = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

