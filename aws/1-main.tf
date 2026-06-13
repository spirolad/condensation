terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  //backend "http" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Version     = var.app_version
      User        = var.user
      Commit      = var.commit
      Branch      = var.branch
      Environment = var.environment
      Terraform   = "true"
    }
  }

}

# VPC with explicit name
resource "aws_vpc" "condensation" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "condensation-${var.environment}-vpc"
  }
}

# Internet Gateway for public access
resource "aws_internet_gateway" "condensation" {
  vpc_id = aws_vpc.condensation.id

  tags = {
    Name = "condensation-${var.environment}-igw"
  }
}

# Public Subnet 1 in first AZ
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.condensation.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "condensation-${var.environment}-public-subnet-1a"
  }
}

# Public Subnet 2 in second AZ
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.condensation.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "condensation-${var.environment}-public-subnet-1b"
  }
}

# Private Subnet 1 for RDS in first AZ
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.condensation.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "condensation-${var.environment}-private-subnet-1a"
  }
}

# Private Subnet 2 for RDS in second AZ
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.condensation.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "condensation-${var.environment}-private-subnet-1b"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.condensation.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.condensation.id
  }

  tags = {
    Name = "condensation-${var.environment}-public-rt"
  }
}

# Associate public subnet 1 with public route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate public subnet 2 with public route table
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Network ACL for public subnets
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.condensation.id
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 4000
    to_port    = 4000
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 8000
    to_port    = 8082
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 9100
    to_port    = 9100
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 160
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "condensation-${var.environment}-public-nacl"
  }
}

