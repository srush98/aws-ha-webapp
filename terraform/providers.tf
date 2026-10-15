# ---------- Terraform and provider versions ----------
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" } # DB password generation
  }
}

# AWS provider; default_tags are applied to every taggable resource
provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "srushti-ha-webapp", ManagedBy = "Terraform" }
  }
}
