resource "aws_s3_bucket" "this" {
  bucket = replace("${var.name}_${var.host}_${var.path}", "_", "-")
  acl = "private"

  force_destroy = true

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET"]
    allowed_origins = ["*"]
    expose_headers  = []
  }
  tags = {
    Name = "${var.name}_${var.host}_${var.path}"
  }
}

resource "aws_cloudfront_origin_access_identity" "this" {
  comment = var.name
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = ["${aws_s3_bucket.this.arn}/*", aws_s3_bucket.this.arn]

    principals {
      type = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id = aws_s3_bucket.this.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  enabled = true

  default_cache_behavior {
    target_origin_id  = aws_s3_bucket.this.bucket

    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    forwarded_values {
      headers = ["Origin"]
      cookies {
        forward = "none"
      }
      query_string = false
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_ssm_parameter" "cdn_url" {
  name = "${var.name}_${var.host}_${var.path}_url"
  type = "String"
  value = aws_cloudfront_distribution.this.domain_name
}

resource "aws_ssm_parameter" "s3_cdn_bucket_name" {
  name = "s3_bucket_cdn_${var.name}_${var.host}_${var.path}"
  type = "String"
  value = aws_s3_bucket.this.bucket
}
