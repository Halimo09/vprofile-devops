terraform {
  backend "s3" {
    bucket         = "vprofile-dev-tfstate-e685d44a"
    key            = "dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "vprofile-dev-terraform-lock"
    encrypt        = true
  }
}
