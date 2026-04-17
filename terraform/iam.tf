############################################
# IAM ROLE
############################################

resource "aws_iam_role" "this" {
  name = "image-builder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

############################################
# AWS MANAGED POLICIES
############################################

resource "aws_iam_role_policy_attachment" "policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ])

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

############################################
# CUSTOM S3 WRITE POLICY (CRITICAL FIX)
############################################

resource "aws_iam_role_policy" "s3_write" {
  name = "image-builder-s3-write"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      }
    ]
  })
}

############################################
# INSTANCE PROFILE
############################################

resource "aws_iam_instance_profile" "this" {
  name = "image-builder-profile"
  role = aws_iam_role.this.name
}