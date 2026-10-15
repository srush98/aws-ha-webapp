# ---------- General ----------
variable "region" { default = "us-east-1" }
variable "name" { default = "tf" }                        # prefix for resource names and SSM paths
variable "azs" { default = ["us-east-1a", "us-east-1b"] } # one subnet per tier in each AZ

# ---------- Networking (one CIDR per AZ, same order as var.azs) ----------
variable "vpc_cidr" { default = "10.1.0.0/16" }
variable "public_cidrs" { default = ["10.1.1.0/24", "10.1.2.0/24"] } # ALB + NAT
variable "app_cidrs" { default = ["10.1.11.0/24", "10.1.12.0/24"] }  # app servers + Prometheus
variable "db_cidrs" { default = ["10.1.21.0/24", "10.1.22.0/24"] }   # RDS, no internet route

# ---------- Application ----------
variable "repo_url" { default = "https://github.com/srush98/aws-ha-webapp.git" } # cloned by user data

# ---------- DNS: app is served at <subdomain>.<domain_name> ----------
variable "domain_name" { default = "srushti.site" } # existing Route 53 hosted zone
variable "subdomain" { default = "terraform" }

# ---------- Monitoring: component versions ----------
variable "node_exporter_version" { default = "1.8.2" } # installed on app servers
variable "monitoring_instance_type" { default = "t3.micro" }
variable "prometheus_version" { default = "3.1.0" }

variable "alertmanager_version" { default = "0.27.0" }
variable "blackbox_version" { default = "0.25.0" }

# ---------- Monitoring: alert thresholds ----------
variable "cpu_alert_threshold" { default = 10 }  # DEMO value; production = 80
variable "disk_alert_threshold" { default = 80 } # percent used
variable "ssl_expiry_alert_days" { default = 30 }
