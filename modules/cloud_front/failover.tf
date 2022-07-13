resource "aws_s3_bucket" "failover" {
  bucket = "failover-${var.name}-${var.host}"
  acl = "private"
  website {
    index_document = "sorry.html"
    error_document = "sorry.html"
  }
}

resource "aws_s3_bucket_object" "sorry_html" {
  bucket = aws_s3_bucket.failover.id
  key = "sorry.html"
  source = "${path.module}/src/sorry.html"
  content_type = "text/html"
  acl = "public-read"
  cache_control = "no-store"
  etag = filemd5("${path.module}/src/sorry.html")
}

resource "aws_cloudfront_origin_access_identity" "failover" {
  comment = var.domain
}

resource "aws_cloudfront_distribution" "failover" {
  origin {
    domain_name = aws_s3_bucket.failover.bucket_regional_domain_name
    origin_id = aws_s3_bucket.failover.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.failover.cloudfront_access_identity_path
    }
  }

  aliases = [
    var.domain,
    "*.${var.domain}"
  ]

  enabled = true

  default_cache_behavior {
    target_origin_id  = aws_s3_bucket.failover.id

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
    default_ttl            = 60
    max_ttl                = 120
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.failover_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method = "sni-only"
  }

  custom_error_response {
    error_code = 403
    error_caching_min_ttl = 10
    response_code = 503
    response_page_path = "/sorry.html"
  }
}
