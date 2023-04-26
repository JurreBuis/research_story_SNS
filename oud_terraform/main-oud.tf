provider "aws" {}

# zip lambda function
data "archive_file" "lambdazip1" {
  type        = "zip"
  output_path = "lambda/zips/lambda_function.zip"
  source_dir  = "lambda/lambda_function"
}

# setup SQS (queue 1)
resource "aws_sqs_queue" "queue-demo-1" {
  name = "queue-demo-1"
  delay_seconds             = 0
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

# setup Lambda
resource "aws_lambda_function" "my_lambda" {
  depends_on = [
    data.archive_file.lambdazip1
  ]

  filename      = "lambda/zips/lambda_function.zip"
  function_name = "order"
  role          = aws_iam_role.iam_demo.arn
  handler       = "current_datetime_lambda.lambda_handler"

  # source_code_hash = filebase64sha256("lambda_function.zip")

  runtime = "python3.9"
  vpc_config {
    subnet_ids         = [aws_subnet.demo_subnet_2.id, aws_subnet.demo_subnet_2.id]
    security_group_ids = [aws_security_group.demo_sg.id]
  }
}


# SNS
resource "aws_sns_topic" "demo-topic" {
  name = "demo-topic"
}

resource "aws_sns_topic_subscription" "email-topic-sub" {
  topic_arn = aws_sns_topic.demo-topic.arn
  protocol  = "email"
  endpoint  = "jfjbuis@gmail.com"

  filter_policy = jsonencode({
    e-mail = ["true"]
  })
}

resource "aws_sns_topic_subscription" "sqs-topic-sub" {
  depends_on = [
    aws_sns_topic.demo-topic,
    aws_sqs_queue.queue-demo-1
  ]

  topic_arn = aws_sns_topic.demo-topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue-demo-1.arn

  filter_policy = jsonencode({
    LambdaSQS = ["true"]
  })
}

resource "aws_sns_topic_subscription" "lambda-topic-sub" {
  depends_on = [
    aws_sns_topic.demo-topic,
    aws_lambda_function.my_lambda
  ]
  topic_arn = aws_sns_topic.demo-topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.my_lambda.arn

  filter_policy = jsonencode({
    LambdaSQS = ["true"]
  })
}

resource "aws_security_group" "demo_sg" {
  name        = "demo-sg"
  description = "Allow traffic to Lambda"
  vpc_id      = aws_vpc.demo_vpc.id
}

# resource "aws_lambda_event_source_mapping" "sqs_lambda_mapping" {
#   event_source_arn = aws_sqs_queue.queue-demo-1.arn
#   function_name    = aws_lambda_function.my_lambda.arn
# }


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

resource "aws_iam_role_policy" "demo_policy" {
  name = "demo-policy"
  role = aws_iam_role.iam_demo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "lambda:InvokeFunction",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full_access" {
  role = aws_iam_role.iam_demo.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}


# setup vpc and subnet
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo-vpc"
  }
}

resource "aws_subnet" "demo_subnet_1" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "demo-subnet-1"
  }
}

resource "aws_subnet" "demo_subnet_2" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "demo-subnet-2"
  }
}