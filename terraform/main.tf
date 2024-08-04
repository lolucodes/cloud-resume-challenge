resource "aws_s3_bucket" "lolucode-click" {
  bucket = var.domain_name
  force_destroy = true

}

resource "aws_s3_bucket" "www-lolucode-click" {
  bucket     = "www.${var.domain_name}"
  depends_on = [aws_s3_bucket.lolucode-click]
  force_destroy = true

}

/*
Configure public access ACLs and policies

- block_public_acls: When set to true, this blocks new public ACLs (access control lists) and removes existing public ACLs. Otherwise, it does not block public ACLs.
- block_public_policy: When set to true, this prevents the application of any new or existing public bucket policies. Otherwise, it does not block public bucket policies.
- ignore_public_acls: When set to true, this ignores public ACLs, meaning that public access granted through ACLs will be ignored and not applied. Otherwise, it does not ignore public ACLs.
- restrict_public_buckets: When set to true, this restricts access to the bucket to only AWS services and authorized users within the AWS account, regardless of the specified bucket policies. Otherwise, it does not restrict public buckets.

*/

resource "aws_s3_bucket_public_access_block" "lolucode-click" {
  bucket = aws_s3_bucket.lolucode-click.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "www-lolucode-click" {
  bucket = aws_s3_bucket.www-lolucode-click.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "lolucode_click_policy" {
  bucket = aws_s3_bucket.lolucode-click.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::zealolu.com/*"
      }
    ]
  })
}


resource "aws_s3_bucket_website_configuration" "lolucode-click" {
  bucket = aws_s3_bucket.lolucode-click.id
#   index_document {
#     suffix = "index.html"
#   }
#   error_document {
#     key = "error.html"
#   }
  redirect_all_requests_to {
    host_name = var.domain_name
    # protocol  = "htt"
  }
}

resource "aws_s3_bucket_website_configuration" "www-lolucode-click" {
  bucket = aws_s3_bucket.www-lolucode-click.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
#   redirect_all_requests_to {
#     host_name = var.domain_name
#     # protocol  = "htt"
#   }
}

# Upload content of the website onto the main bucket
resource "null_resource" "upload_files" {
  depends_on = [aws_s3_bucket.lolucode-click]
  provisioner "local-exec" {
    command = <<EOF
        aws s3 cp --recursive /Users/alveo/Documents/cloud-resume-challenge/website s3://${aws_s3_bucket.lolucode-click.bucket}/ --profile terraform
        EOF
  }
}



# Create Lambda function
data "archive_file" "zippedLambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/zippedLambda.zip"
}

# Create Lambda Function URL
resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.lolcuode-click-views.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

# IAM rule for Lambda to access DynamoDB
resource "aws_lambda_function" "lolcuode-click-views" {
  filename         = data.archive_file.zippedLambda.output_path
  source_code_hash = data.archive_file.zippedLambda.output_base64sha256
  function_name    = "lolcuode-click-views"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.handler"
  runtime          = "python3.10"
}


resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "lolucode.click-count"
  billing_mode   = "PAY_PER_REQUEST"
  # read_capacity  = 20
  # write_capacity = 20
  hash_key       = "id"
  # range_key      = "GameTitle"

  attribute {
    name = "id"
    type = "N"
  }
  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM for Lambda to access the DynamoDB
resource "aws_iam_policy" "iam_policy_for_cloud_resume" {
  name        = "aws_iam_policy_for_cloud_resume_policy"
  path        = "/"
  description = "AWS IAM Policy for managing the cloud resume role"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:*:*:*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem"
          ],
          "Resource" : "arn:aws:dynamodb:*:*:table/lolucode.click-count"
        },
      ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_cloud_resume.arn
}



################################################################################
# Route 53
################################################################################
# To get the hosted zone to be use in argocd domain
data "aws_route53_zone" "this" {
  name         = var.domain_name
#   private_zone = local.is_route53_private_zone
}




# CloudFront Distribution

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access Identity for S3 bucket"
}


locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "example"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = aws_s3_bucket.lolucode-click.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  # logging_config {
  #   include_cookies = false
  #   bucket          = "mylogs.s3.amazonaws.com"
  #   prefix          = "myprefix"
  # }

  aliases = ["resume.zealolu.com"] # Replace with your domain


  price_class = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }


  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn            = module.acm.acm_certificate_arn
    ssl_support_method              = "sni-only"
    minimum_protocol_version        = "TLSv1.2_2021"
  }

}





module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = var.domain_name
  zone_id      = data.aws_route53_zone.this.zone_id

  validation_method = "DNS"

  subject_alternative_names = [
    "resume.zealolu.com",
  ]

  wait_for_validation = true

  tags = {
    Name = var.domain_name
  }
}