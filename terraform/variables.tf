variable "region" { default = "us-east-1" }
variable "name" { default = "tf" }
variable "azs" { default = ["us-east-1a", "us-east-1b"] }

variable "vpc_cidr" { default = "10.1.0.0/16" }
variable "public_cidrs" { default = ["10.1.1.0/24", "10.1.2.0/24"] }
variable "app_cidrs" { default = ["10.1.11.0/24", "10.1.12.0/24"] }
variable "db_cidrs" { default = ["10.1.21.0/24", "10.1.22.0/24"] }

variable "repo_url" { default = "https://github.com/srush98/aws-ha-webapp.git" }

variable "domain_name" { default = "srushti.site" }
variable "subdomain" { default = "terraform" }

variable "node_exporter_version" { default = "1.8.2" }
variable "monitoring_instance_type" { default = "t3.micro" }
variable "prometheus_version" { default = "3.1.0" }

variable "alertmanager_version" { default = "0.27.0" }
variable "blackbox_version" { default = "0.25.0" }
variable "cpu_alert_threshold" { default = 10 } # DEMO value; production = 80
variable "disk_alert_threshold" { default = 80 }
variable "ssl_expiry_alert_days" { default = 30 }