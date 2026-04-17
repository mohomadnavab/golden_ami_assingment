resource "aws_kms_key" "ami" {
  description             = "KMS key for AMI encryption"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "ami_alias" {
  name          = "alias/golden-ami"
  target_key_id = aws_kms_key.ami.key_id
}
