terraform {
  backend "s3" {
    bucket         = "mr-engineers-hackyeah26-terraform-state-bucket"
    key            = "one-infrastructure/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
  }
}
