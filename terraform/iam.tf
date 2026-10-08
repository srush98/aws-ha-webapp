data "aws_caller_identity" "current" {}

# Who may assume the role: only the EC2 service
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager access (no SSH)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least privilege: read own DB parameters; write-only to the log bucket
resource "aws_iam_role_policy" "app" {
  name = "${var.name}-app-policy"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.name}/db/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/tomcat/*"
      },
      {
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.logs.arn
        Condition = { StringLike = { "s3:prefix" = ["tomcat/*"] } }
      }
    ]
  })
}

# EC2 attaches roles through an instance profile
resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-ec2-profile"
  role = aws_iam_role.app.name
}