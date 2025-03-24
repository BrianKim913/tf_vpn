region = "ap-northeast-2"
vpn_vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a"]
openvpn_ami = "ami-09a093fa2e3bfca5a"  # aws에서 ami 확인 및 필요시 수정
key_name = "test-vpn-key"  # 나의 발급받은 키 네임으로 수정
private_key_path = "~/.ssh/test-vpn-key.pem"  # 나의 키파일 경로로 수정