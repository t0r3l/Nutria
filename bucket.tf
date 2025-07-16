# main.tf

# 1. Configure le provider AWS
provider "aws" {
  region = "eu-west-3"  # Paris
}

# 2. Crée un bucket S3
resource "aws_s3_bucket" "mon_bucket" {
  bucket = "nutria-bucket-products"  # Nom globalement unique

  tags = {
    Environment = "dev"
    Project     = "nutria"
  }
}

# 3. Active le versioning (optionnel)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.mon_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 4. Upload un fichier local vers le bucket
resource "aws_s3_object" "fichier" {
  bucket = aws_s3_bucket.mon_bucket.id
  key    = "test.csv"  # chemin et nom dans S3
  source = "${path.module}/data_prep/data/products_names_with_macro_nutriments.csv"          # fichier local à uploader
  etag   = filemd5("${path.module}/data_prep/data/products_names_with_macro_nutriments.csv") # force re-upload si le contenu change

  content_type = "text/plain"  # ou détecté automatiquement
}

# 5. (Optionnel) Outputs
output "bucket_name" {
  value = aws_s3_bucket.mon_bucket.id
}

output "object_url" {
  value = aws_s3_object.fichier.id  # sous la forme bucket/key
}

# TODO : Vérifier accès au fichier du bucket via url