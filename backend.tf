# backend.tf

terraform {
  backend "s3" {
    bucket         = "awsestudio2025-terraform-state" # Reemplazar con el nombre de tu bucket S3 creado manualmente
    key            = "vpc-project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks" # Opcional, pero recomendado para bloqueos
  }
}