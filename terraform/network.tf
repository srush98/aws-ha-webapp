# =====================================================================
# Network: VPC with three tiers (public / app / db) across two AZs
# =====================================================================

# ---------- VPC and internet gateway ----------
# DNS support/hostnames are needed for RDS endpoints and VPC endpoints
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-igw" }
}

# ---------- Subnets (one per AZ per tier) ----------
# Name suffix is the AZ letter, e.g. us-east-1a -> "1a"

# Public: ALB and NAT gateway
resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "${var.name}-public-${element(split("-", var.azs[count.index]), 2)}" }
}

# Private app: app servers and Prometheus; outbound via NAT
resource "aws_subnet" "app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "${var.name}-private-app-${element(split("-", var.azs[count.index]), 2)}" }
}

# Private DB: RDS only; no route to the internet
resource "aws_subnet" "db" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "${var.name}-private-db-${element(split("-", var.azs[count.index]), 2)}" }
}

# ---------- NAT gateway ----------
# Single NAT in the first public subnet (cost saving; not AZ-redundant)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-natgw" }
  depends_on    = [aws_internet_gateway.igw]
}

# ---------- Route tables ----------
# Public: default route to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.name}-public-rt" }
}

# App: default route to the NAT gateway (outbound only)
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.name}-app-rt" }
}

# DB: local VPC route only
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-db-rt" }
}

# ---------- Route table associations ----------
resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "db" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ---------- VPC endpoints ----------
# S3 gateway endpoint: app servers reach S3 (log uploads) without the NAT; free
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id]
  tags              = { Name = "${var.name}-s3-endpoint" }
}
