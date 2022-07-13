resource "aws_s3_bucket" "this"  {
  bucket = var.host.bucket_name
  acl = "private"
}

data "aws_s3_bucket" "help" {
  bucket = var.host.help_bucket_name
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.name}-${var.host_name}-logs${var.suffix}"

  acl = "private"
}

data "aws_elb_service_account" "this" {}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
        ],
        "Resource": [
          "${aws_s3_bucket.logs.arn}/*"
        ],
        "Principal": {
          "AWS": data.aws_elb_service_account.this.id
        }
      }
    ]
  })
}

resource "aws_iam_policy" "this" {
  name = "S3Access_${var.name}_${var.host_name}${var.suffix}"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": [
          "${aws_s3_bucket.this.arn}",
          "${aws_s3_bucket.this.arn}/*",
          "${data.aws_s3_bucket.help.arn}",
          "${data.aws_s3_bucket.help.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_ssm_parameter" "s3_bucket_name" {
  name = "s3_bucket_${var.name}_${var.host_name}"
  type = "String"
  value = aws_s3_bucket.this.bucket
}

resource "aws_ssm_parameter" "help_s3_bucket_name" {
  name = "help_s3_bucket_${var.name}_${var.host_name}"
  type = "String"
  value = data.aws_s3_bucket.help.bucket
}
