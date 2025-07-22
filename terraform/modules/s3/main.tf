# S3 Bucket for nutrition data
resource "aws_s3_bucket" "nutrition_data" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = var.bucket_name
      Description = "Stores nutrition data CSV files"
    }
  )
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "nutrition_data_versioning" {
  bucket = aws_s3_bucket.nutrition_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "nutrition_data_encryption" {
  bucket = aws_s3_bucket.nutrition_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "nutrition_data_pab" {
  bucket = aws_s3_bucket.nutrition_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.nutrition_data]
}

# Upload CSV file
resource "aws_s3_object" "products_csv" {
  bucket = aws_s3_bucket.nutrition_data.id
  key    = var.csv_file_key
  source = var.csv_file_path
  etag   = filemd5(var.csv_file_path)

  tags = merge(
    var.tags,
    {
      Name        = "Products nutrition data"
      Description = "CSV file containing product nutrition information"
    }
  )

  depends_on = [aws_s3_bucket.nutrition_data]
}