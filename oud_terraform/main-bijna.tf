provider "aws" {}

# zip lambda function
data "archive_file" "lambdazip1" {
  type        = "zip"
  output_path = "lambda/zips/lambda_function_sns.zip"
  source_dir  = "lambda/lambda_function_sns"
}

# setup SQS (queue 1)
resource "aws_sqs_queue" "queue-demo-1" {
  name = "queue-demo-1"
  
  visibility_timeout_seconds  = 30
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  message_retention_seconds   = 84600
  max_message_size            = 262144
}

# setup Lambda
resource "aws_lambda_function" "my_lambda" {
  depends_on = [
    data.archive_file.lambdazip1
  ]

  filename      = "lambda/zips/lambda_function_sns.zip"
  function_name = "sns_test"
  role          = aws_iam_role.iam_demo.arn
  handler       = "sns_test_function.lambda_handler"

  # source_code_hash = filebase64sha256("lambda_function.zip")

  runtime = "python3.9"
}


# SNS
resource "aws_sns_topic" "demo-topic" {
  name = "demo-topic"
}

# # e-mail subscription to SNS topic
# resource "aws_sns_topic_subscription" "email-topic-sub" {
#   topic_arn = aws_sns_topic.demo-topic.arn
#   protocol  = "email"
#   endpoint  = "jfjbuis@gmail.com"

#   filter_policy = jsonencode({
#     e-mail = ["true"]
#   })
# }

# SQS subscription to SNS topic
resource "aws_sns_topic_subscription" "sqs-topic-sub" {
  depends_on = [
    aws_sns_topic.demo-topic,
    aws_sqs_queue.queue-demo-1
  ]

  topic_arn = aws_sns_topic.demo-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue-demo-1.arn
  raw_message_delivery = true

  # filter_policy = jsonencode({
  #   LambdaSQS = ["true"]
  # })
}

# # Lambda subscription to SNS topic
# resource "aws_sns_topic_subscription" "lambda-topic-sub" {
#   depends_on = [
#     aws_sns_topic.demo-topic,
#     aws_lambda_function.my_lambda
#   ]
#   topic_arn = aws_sns_topic.demo-topic.arn
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.my_lambda.arn

#   filter_policy = jsonencode({
#     LambdaSQS = ["true"]
#   })
# }

resource "aws_lambda_event_source_mapping" "sqs_lambda_mapping" {
  event_source_arn = aws_sqs_queue.queue-demo-1.arn
  function_name    = aws_lambda_function.my_lambda.arn
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

resource "aws_iam_policy" "demo_policy" {
  name = "demo-policy"
  description = "An example policy that allows access to Lambda, SQS, SNS, and CloudWatch."
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "lambda:*",
          "sqs:*",
          "sns:*",
          "cloudwatch:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_full_access" {
  policy_arn = aws_iam_policy.demo_policy.arn
  role       = aws_iam_role.iam_demo.name
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
