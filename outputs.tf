output "openvpn_public_ip" {
  description = "Public IP address of the OpenVPN server"
  value       = aws_eip.openvpn.public_ip
}

output "vpn_vpc_id" {
  description = "ID of the VPN VPC"
  value       = aws_vpc.vpn_vpc.id
}

output "vpn_vpc_cidr" {
  description = "CIDR block of the VPN VPC"
  value       = aws_vpc.vpn_vpc.cidr_block
}

output "vpn_public_subnet_ids" {
  description = "IDs of the VPN public subnets"
  value       = aws_subnet.vpn_public[*].id
}