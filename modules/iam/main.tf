# EC2 instance role — allows collectors to call AWS APIs + Bedrock
resource "aws_iam_role" "app_role" {
  name = "${var.project}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.app_role.name
  tags = var.tags
}

# Bedrock invocation — Claude Sonnet + Titan Embeddings only
resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.project}-bedrock-access"
  description = "Allow invocation of specific Bedrock models for governance copilot"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvokeModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
          "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      }
    ]
  })

  tags = var.tags
}

# Security read-only — for collectors
resource "aws_iam_policy" "security_readonly" {
  name        = "${var.project}-security-readonly"
  description = "Read-only access to security services for governance copilot collectors"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:List*",
          "iam:Get*",
          "iam:GenerateCredentialReport",
          "iam:GenerateServiceLastAccessedDetails"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadOnly"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketVersioning",
          "s3:GetBucketEncryption",
          "s3:GetBucketLogging",
          "s3:GetLifecycleConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "GuardDutyReadOnly"
        Effect = "Allow"
        Action = [
          "guardduty:List*",
          "guardduty:Get*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailReadOnly"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSReadOnly"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaReadOnly"
        Effect = "Allow"
        Action = [
          "lambda:List*",
          "lambda:Get*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CostExplorer"
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "ce:GetAnomalies",
          "ce:GetAnomalyMonitors",
          "ce:GetDimensionValues"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityHub"
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:ListFindings",
          "securityhub:DescribeHub"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# S3 app cache access
resource "aws_iam_policy" "s3_cache_access" {
  name        = "${var.project}-s3-cache-access"
  description = "Allow app to read/write S3 cache bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3CacheAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-app-cache-*",
          "arn:aws:s3:::${var.project}-app-cache-*/*"
        ]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

resource "aws_iam_role_policy_attachment" "security_readonly" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.security_readonly.arn
}

resource "aws_iam_role_policy_attachment" "s3_cache" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.s3_cache_access.arn
}
