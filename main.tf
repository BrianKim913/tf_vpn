terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# OpenVPN VPC
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = var.vpn_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpn-vpc"
  }
}

# Internet Gateway for VPN VPC
resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "vpn-igw"
  }
}

# Public Subnets for VPN VPC
resource "aws_subnet" "vpn_public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = cidrsubnet(var.vpn_vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "vpn-public-subnet-${count.index + 1}"
  }
}

# Private Subnets for Transit Gateway
resource "aws_subnet" "vpn_private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = cidrsubnet(var.vpn_vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "vpn-private-subnet-${count.index + 1}"
  }
}

# Route Table for VPN Public Subnets
resource "aws_route_table" "vpn_public" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # production은 워크 스페이스, 집 ip로 접근 제한 필요
    gateway_id = aws_internet_gateway.vpn_igw.id
  }

  tags = {
    Name = "vpn-public-route-table"
  }
}

# Route Table for VPN Private Subnets
resource "aws_route_table" "vpn_private" {
  vpc_id = aws_vpc.vpn_vpc.id

  # Transit gateway가 자동 생성
  
  tags = {
    Name = "vpn-private-route-table"
  }
}

# Route Table Association for VPN Public Subnets
resource "aws_route_table_association" "vpn_public" {
  count          = length(aws_subnet.vpn_public)
  subnet_id      = aws_subnet.vpn_public[count.index].id
  route_table_id = aws_route_table.vpn_public.id
}

# Route Table Association for VPN Private Subnets
resource "aws_route_table_association" "vpn_private" {
  count          = length(aws_subnet.vpn_private)
  subnet_id      = aws_subnet.vpn_private[count.index].id
  route_table_id = aws_route_table.vpn_private.id
}

# Security Group for OpenVPN Server
resource "aws_security_group" "vpn_sg" {
  name        = "vpn-security-group"
  description = "Security group for OpenVPN server"
  vpc_id      = aws_vpc.vpn_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 워크스페이스, 집 ip로 접근 제한 해야 할듯

  # OpenVPN UDP
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # OpenVPN Web Admin
  ingress {
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS for OpenVPN Web Admin (if needed)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpn-security-group"
  }
}

# EC2 Instance for OpenVPN
resource "aws_instance" "openvpn" {
  ami                    = var.openvpn_ami # OpenVPN AMI
  instance_type          = "t2.small"
  subnet_id              = aws_subnet.vpn_public[0].id
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]
  key_name               = var.key_name
  
  user_data = file("${path.module}/openvpn-setup.sh")
  
  tags = {
    Name = "openvpn-server"
  }
}

# Elastic IP for OpenVPN Server
resource "aws_eip" "openvpn" {
  domain   = "vpc"
  instance = aws_instance.openvpn.id
  
  tags = {
    Name = "openvpn-eip"
  }
}