variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "csv_file_path" {
  description = "Path to local CSV file to upload"
  type        = string
}

variable "csv_file_key" {
  description = "S3 key for the CSV file"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}