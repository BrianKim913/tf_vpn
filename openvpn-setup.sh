#!/bin/bash
# This script configures an existing OpenVPN Access Server installation
# to allow access to an EKS cluster in a separate VPC

# Wait for the OpenVPN Access Server to fully initialize
echo "Waiting for OpenVPN Access Server to initialize..."
sleep 90  # Increased wait time to ensure full initialization

# Set admin password
echo "Setting admin password..."
ADMIN_PASSWORD="123qwe123" # Change this to your desired password
# Use the correct method to set the OpenVPN admin password
sudo /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$ADMIN_PASSWORD" SetLocalPassword

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure OpenVPN server settings using sacli
echo "Configuring OpenVPN server settings..."
# Set server hostname to public IP
sudo /usr/local/openvpn_as/scripts/sacli --key "host.name" --value "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" ConfigPut

# Configure standard ports
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.daemon.tcp.port" --value "443" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.daemon.udp.port" --value "1194" ConfigPut

# Configure both VPC CIDR blocks for routing
# OpenVPN server's VPC
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_network.0" --value "10.0.0.0/16" ConfigPut
# EKS cluster's VPC
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_network.1" --value "10.1.0.0/16" ConfigPut

# Enable client-to-client routing (allows VPN clients to communicate with each other)
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_access" --value "true" ConfigPut

# Push DNS servers to clients that match your VPC DNS
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.dhcp_option.dns.0" --value "10.0.0.2" ConfigPut

# Enable NAT for both VPC CIDR blocks
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.nat.enable" --value "true" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.nat.netmask.0" --value "10.0.0.0/16" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.nat.netmask.1" --value "10.1.0.0/16" ConfigPut

# Use split tunneling (only route VPC traffic through VPN)
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_gw" --value "false" ConfigPut

# Create a client profile
echo "Creating client profile..."
sudo /usr/local/openvpn_as/scripts/sacli --user client1 --key "prop_autologin" --value "true" UserPropPut
sudo /usr/local/openvpn_as/scripts/sacli --user client1 --key "prop_superuser" --value "false" UserPropPut
sudo /usr/local/openvpn_as/scripts/sacli --user client1 --new_pass "ClientPassword123" SetLocalPassword

# Create an admin user profile
echo "Creating admin profile..."
sudo /usr/local/openvpn_as/scripts/sacli --user admin --key "prop_autologin" --value "true" UserPropPut
sudo /usr/local/openvpn_as/scripts/sacli --user admin --key "prop_superuser" --value "true" UserPropPut
sudo /usr/local/openvpn_as/scripts/sacli --user admin --new_pass "AdminPassword123" SetLocalPassword

# Apply changes and restart services
echo "Applying changes and restarting services..."
sudo /usr/local/openvpn_as/scripts/sacli start

# Generate client configuration profiles
echo "Generating client profiles for download..."
mkdir -p /tmp/client_profiles

# Generate client1 profile
CLIENT1_PROFILE=$(sudo /usr/local/openvpn_as/scripts/sacli --user client1 GetAutologin)
echo "$CLIENT1_PROFILE" > /tmp/client_profiles/client1.ovpn

# Generate admin profile
ADMIN_PROFILE=$(sudo /usr/local/openvpn_as/scripts/sacli --user admin GetAutologin)
echo "$ADMIN_PROFILE" > /tmp/client_profiles/admin.ovpn

# Set readable permissions
chmod 644 /tmp/client_profiles/*.ovpn

# Display information about how to connect
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "OpenVPN Access Server has been configured!"
echo "Admin web interface: https://$PUBLIC_IP:943/admin"
echo "Admin username: openvpn"
echo "Admin password: $ADMIN_PASSWORD"
echo ""
echo "Client profiles have been generated in /tmp/client_profiles/"
echo "Use 'scp' to download them to your local machine:"
echo "scp -i your-key.pem ec2-user@$PUBLIC_IP:/tmp/client_profiles/*.ovpn ."
echo ""
echo "Alternative URLs for client profiles:"
echo "https://$PUBLIC_IP:943/?src=connect client1"
echo "https://$PUBLIC_IP:943/?src=connect admin"
echo ""
echo "IMPORTANT: Make sure your AWS VPC routing is properly configured:"
echo "- Verify there's a route between the 10.0.0.0/16 VPC and 10.1.0.0/16 VPC"
echo "- Check that security groups allow traffic between VPCs and from VPN clients"