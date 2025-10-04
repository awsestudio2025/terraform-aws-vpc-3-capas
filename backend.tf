# backend.tf

terraform {
  backend "s3" {
    bucket         = "awsestudio2025-terraform-state" # Reemplazar con el nombre de tu bucket S3 creado manualmente
    key            = "vpc-project/terraform.tfstate"
    region         = var.aws_region
    encrypt        = true
  }
}