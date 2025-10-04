terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "access_key" {
  type = string
}

variable "secret_key" {
  type = string
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}


variable "vpc_cidr" {
  type = list
}

variable "subnet_cidr1" {
  type = list
}

variable "subnet_cidr2" {
  type = list
}

resource "aws_vpc" "VPC-01" {
  cidr_block = var.vpc_cidr[0]
  
  tags = {
    Name = "OnPrem"
  }
}
resource "aws_vpc" "VPC-02" {
  cidr_block = var.vpc_cidr[1]
  
  tags = {
    Name = "AWSVPC"
  }
}

resource "aws_internet_gateway" "VPC-01-IGW" {
  vpc_id = aws_vpc.VPC-01.id
}

resource "aws_internet_gateway" "VPC-02-IGW" {
  vpc_id = aws_vpc.VPC-02.id
}

resource "aws_subnet" "VPC-01-Subnet-01" {
  vpc_id            = aws_vpc.VPC-01.id
  cidr_block        = var.subnet_cidr1[0]
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "VPC-01-Subnet"
  }
}

resource "aws_subnet" "VPC-02-Subnet-01" {
  vpc_id            = aws_vpc.VPC-02.id
  cidr_block        = var.subnet_cidr2[0]
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "VPC-02-Subnet"
  }
}

resource "aws_security_group" "EC2-SG01" {
  name        = "EC2-SG01"
  #description = "Allow SSH and HTTP access"
  vpc_id      = aws_vpc.VPC-01.id

  # Inbound rules
  ingress {
    from_port   = 22   
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = 80     
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }
  
  ingress {
    from_port   = 443     
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = -1    
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  # Outbound rules (optional, default allows all outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name = "EC2-SG01"
  }
}

resource "aws_security_group" "EC2-SG02" {
  name        = "EC2-SG02"
  #description = "Allow SSH and HTTP access"
  vpc_id      = aws_vpc.VPC-02.id

  # Inbound rules
  ingress {
    from_port   = 22   
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = 80     
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }
  
  ingress {
    from_port   = 443     
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = -1    
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  # Outbound rules (optional, default allows all outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name = "EC2-SG02"
  }
}


resource "aws_instance" "VPC-01-EC2-01" {
  subnet_id = aws_subnet.VPC-01-Subnet-01.id
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  key_name      = "home134-publickey"
  #associate_public_ip_address = true
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.EC2-SG01.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo apt install strongswan -y
                sudo systemctl start apache2
                echo "<h1>Server Details</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>" | sudo tee /var/www/html/index.html > /dev/null
                EOF

  tags = {
     Name = "StrongSwanGW"
  }
}

# Allocate Elastic IP
resource "aws_eip" "VPC-01-EC2-01-EIP" {
  instance = aws_instance.VPC-01-EC2-01.id
  vpc = true
}

resource "aws_instance" "VPC-01-EC2-02" {
  subnet_id = aws_subnet.VPC-01-Subnet-01.id
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  key_name      = "home134-publickey"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.EC2-SG01.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                echo "<h1>Server Details</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>" | sudo tee /var/www/html/index.html > /dev/null
                EOF

  tags = {
     Name = "OnPremHost"
  }
}


resource "aws_instance" "VPC-02-EC2-01" {
  subnet_id = aws_subnet.VPC-02-Subnet-01.id
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  key_name      = "home134-publickey"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.EC2-SG02.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                echo "<h1>Server Details</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>" | sudo tee /var/www/html/index.html > /dev/null
                EOF

  tags = {
     Name = "AWSHost"
  }
}

output "VPC-01-EC2-01-Elastic-IP" {
  value = aws_eip.VPC-01-EC2-01-EIP.public_ip
}

output "VPC-01-EC2-02-Public-IP" {
  value = aws_instance.VPC-01-EC2-02.public_ip
}

output "VPC-02-EC2-01-Public-IP" {
  value = aws_instance.VPC-02-EC2-01.public_ip
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "VPC-02-VGW" {
  amazon_side_asn = "64512"
  vpc_id = aws_vpc.VPC-02.id
  tags = {
    Name = "VPC-02-VGW"
  }
}

# Customer Gateway (your on-prem/public router)
resource "aws_customer_gateway" "VPC-01-CGW" {
  #bgp_asn    = var.cgw_bgp_asn
  ip_address = aws_eip.VPC-01-EC2-01-EIP.public_ip
  type       = "ipsec.1"
  tags = {
    Name = "VPC-01-CGW"
  }
}

# VPN Connection
resource "aws_vpn_connection" "VPC-01-VPC-02-VPN" {
  customer_gateway_id = aws_customer_gateway.VPC-01-CGW.id
  type                = "ipsec.1"
  vpn_gateway_id      = aws_vpn_gateway.VPC-02-VGW.id
  static_routes_only  = true

  tags = {
    Name = "VPC-01-VPC-02-VPN"
  }
}

# Optional: Add static route
resource "aws_vpn_connection_route" "VPN-Route" {
  destination_cidr_block = var.vpc_cidr[0]
  vpn_connection_id = aws_vpn_connection.VPC-01-VPC-02-VPN.id
}


resource "aws_route_table" "VPC-01-Subnet-01-RT" {
  vpc_id = aws_vpc.VPC-01.id

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet access
    gateway_id = aws_internet_gateway.VPC-01-IGW.id
  }

  tags = {
    Name = "VPC-01-Subnet-01-RT"
  }
}

resource "aws_route_table" "VPC-02-Subnet-01-RT" {
  vpc_id = aws_vpc.VPC-02.id

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet access
    gateway_id = aws_internet_gateway.VPC-02-IGW.id
  }
    
  tags = {
    Name = "VPC-02-Subnet-01-RT"
  }
}

resource "aws_route" "VPC-02-VPN-route" {
  route_table_id         = aws_route_table.VPC-02-Subnet-01-RT.id
  destination_cidr_block = var.vpc_cidr[0]
  gateway_id             = aws_vpn_gateway.VPC-02-VGW.id
}


resource "aws_route_table_association" "VPC-01-Subnet-01-RT" {
  subnet_id      = aws_subnet.VPC-01-Subnet-01.id
  route_table_id = aws_route_table.VPC-01-Subnet-01-RT.id
}

resource "aws_route_table_association" "VPC-02-Subnet-01-RT" {
  subnet_id      = aws_subnet.VPC-02-Subnet-01.id
  route_table_id = aws_route_table.VPC-02-Subnet-01-RT.id
}


