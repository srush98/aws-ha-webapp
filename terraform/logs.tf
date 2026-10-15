# ---------- Tomcat log bucket: private, encrypted, TLS-only, 30-day expiry ----------
# Bucket names are global, so the account ID is appended
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name}-tomcat-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # lab: lets `terraform destroy` remove it with logs inside
  tags          = { Name = "${var.name}-tomcat-logs" }
}

# Block every form of public access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt objects at rest with S3-managed keys (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Delete logs under tomcat/ after 30 days; clean up failed uploads after 1 day
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-tomcat-logs-30d"
    status = "Enabled"
    filter {
      prefix = "tomcat/"
    }
    expiration {
      days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Deny any request not made over HTTPS
data "aws_iam_policy_document" "logs_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Applied after the public access block to avoid conflicting API calls
resource "aws_s3_bucket_policy" "logs" {
  bucket     = aws_s3_bucket.logs.id
  policy     = data.aws_iam_policy_document.logs_tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.logs]
}
