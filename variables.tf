variable "region" {
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "vpn_vpc_cidr" {
  description = "CIDR block for the VPN VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "openvpn_ami" {
  description = "AMI ID for the OpenVPN server"
}

variable "key_name" {
  description = "Key pair name for SSH access to OpenVPN server"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key file"
  type        = string
}