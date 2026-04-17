resource "random_id" "bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "logs" {
  bucket = "image-builder-logs-${random_id.bucket.hex}"
}
