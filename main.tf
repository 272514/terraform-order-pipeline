provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
}

provider "archive" {}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
