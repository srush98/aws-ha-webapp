variable "region" { default = "us-east-1" }
variable "name" { default = "tf" }
variable "azs" { default = ["us-east-1a", "us-east-1b"] }

variable "vpc_cidr" { default = "10.1.0.0/16" }
variable "public_cidrs" { default = ["10.1.1.0/24", "10.1.2.0/24"] }
variable "app_cidrs" { default = ["10.1.11.0/24", "10.1.12.0/24"] }
variable "db_cidrs" { default = ["10.1.21.0/24", "10.1.22.0/24"] }

variable "repo_url" { default = "https://github.com/srush98/aws-ha-webapp.git" }