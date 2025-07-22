output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.nutrition_data.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.nutrition_data.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.nutrition_data.bucket
}

output "csv_object_key" {
  description = "S3 key of the uploaded CSV file"
  value       = aws_s3_object.products_csv.key
}