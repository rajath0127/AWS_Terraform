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

variable "availability_zone" {
  type = list
}

variable "subnet_cidr" {
  type = list
}


resource "aws_vpc" "VPC-01" {
  cidr_block = var.vpc_cidr[0]
  
  tags = {
    Name = "VPC-01"
  }
 
}

resource "aws_vpc" "VPC-02" {
  cidr_block = var.vpc_cidr[1]
  
  tags = {
    Name = "VPC-02"
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
  cidr_block        = var.subnet_cidr[0]
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "VPC-01-Subnet-01"
  }
}

resource "aws_subnet" "VPC-02-Subnet-01" {
  vpc_id            = aws_vpc.VPC-02.id
  cidr_block        = var.subnet_cidr[1]
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "VPC-02-Subnet-01"
  }
}

variable "instance_names" {
  default = ["VPC-01-EC2-01", "VPC-02-EC2-01"]
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
  key_name      = "My_EC2_1_Key"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.EC2-SG01.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo '<h1>Server Details:</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>' > /var/www/html/index.html"
                EOF

  tags = {
     Name = "VPC-01-EC2-01"
  }
}

resource "aws_instance" "VPC-02-EC2-01" {
  subnet_id = aws_subnet.VPC-02-Subnet-01.id
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  key_name      = "My_EC2_1_Key"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.EC2-SG02.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo '<h1>Server Details:</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>' > /var/www/html/index.html"
                EOF

  tags = {
     Name = "VPC-02-EC2-01"
  }
}

output "VPC-01-EC2-Public-IP" {
  value = aws_instance.VPC-01-EC2-01.public_ip
}

output "VPC-02-EC2-Public-IP" {
  value = aws_instance.VPC-02-EC2-01.public_ip
}

resource "aws_route_table" "VPC-01-Subnet-01-RT" {
  vpc_id = aws_vpc.VPC-01.id

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet access
    gateway_id = aws_internet_gateway.VPC-01-IGW.id
  }

  route {
    cidr_block = var.vpc_cidr[1]  # Route for VPC-02
    vpc_peering_connection_id = aws_vpc_peering_connection.VPC-Peering.id
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

  route {
    cidr_block = var.vpc_cidr[0]  # Route for VPC-01
    vpc_peering_connection_id = aws_vpc_peering_connection.VPC-Peering.id
  }

  tags = {
    Name = "VPC-02-Subnet-01-RT"
  }
}

resource "aws_route_table_association" "VPC-01-Subnet-01-RT" {
  subnet_id      = aws_subnet.VPC-01-Subnet-01.id
  route_table_id = aws_route_table.VPC-01-Subnet-01-RT.id
}

resource "aws_route_table_association" "VPC-02-Subnet-01-RT" {
  subnet_id      = aws_subnet.VPC-02-Subnet-01.id
  route_table_id = aws_route_table.VPC-02-Subnet-01-RT.id
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "VPC-Peering" {
  vpc_id        = aws_vpc.VPC-01.id
  peer_vpc_id   = aws_vpc.VPC-02.id
  #peer_region   = "us-east-1" # Required if VPCs are in different regions
  auto_accept   = false       # Set to true if the accepter VPC is in the same AWS account

  tags = {
    Name = "VPC-Peering-Connection"
  }
}

# Accept the Peering Request (Required if auto_accept = false)
resource "aws_vpc_peering_connection_accepter" "Peer-Accept" {
  vpc_peering_connection_id = aws_vpc_peering_connection.VPC-Peering.id
  auto_accept               = true

  tags = {
    Name = "VPC-Peering-Connection-Accepter"
  }
}
