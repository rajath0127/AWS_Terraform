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
  type = string
}

variable "subnet_cidr" {
  type = list
}

variable "availability_zone" {
  type = list
}

resource "aws_vpc" "VPC-01" {
  cidr_block = var.vpc_cidr
  
  tags = {
    Name = "VPC-01"
  }
 
}

resource "aws_internet_gateway" "VPC-01-IGW" {
  vpc_id = aws_vpc.VPC-01.id
}

resource "aws_subnet" "VPC-01-Subnet-01" {
  vpc_id            = aws_vpc.VPC-01.id
  cidr_block        = var.subnet_cidr[0]
  availability_zone = var.availability_zone[0]
  
  tags = {
    Name = "VPC-01-Subnet-01"
  }
}

resource "aws_subnet" "VPC-01-Subnet-02" {
  vpc_id            = aws_vpc.VPC-01.id
  cidr_block        = var.subnet_cidr[1]
  availability_zone = var.availability_zone[1]
  
  tags = {
    Name = "VPC-01-Subnet-02"
  }
}


resource "aws_eip" "VPC-01-NGW-EIP" {
  #vpc = true  # Specify that this EIP is for use in a VPC

  tags = {
     Name = "VPC-01-Subnet01-NGW-EIP"
  }
}

resource "aws_nat_gateway" "VPC-01-NGW" {
  allocation_id = aws_eip.VPC-01-NGW-EIP.id
  subnet_id     = aws_subnet.VPC-01-Subnet-01.id

  tags = {
     Name = "VPC-01-Subnet01-NGW"
  }
}


/*
resource "aws_key_pair" "My_EC2_1_Key" {
  key_name   = "My_EC2_1_Key"  # Change to your key pair name
  public_key = file("C:\\Users\\rajat\\OneDrive\\Documents\\Terraform\\My_EC2_1_Key.pem")  # Path to your public key file
}
*/

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

resource "aws_instance" "VPC-01-EC2-02" {
  subnet_id = aws_subnet.VPC-01-Subnet-02.id
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.EC2-SG01.id]
  key_name      = "My_EC2_1_Key"

  tags = {
    Name = "VPC-01-EC2-02"
  }
}


output "EC2-01-Public-IP" {
  value = aws_instance.VPC-01-EC2-01.public_ip
}

output "VPC-01-NAT-GW-EIP" {
  value = aws_eip.VPC-01-NGW-EIP.public_ip
}

resource "aws_route_table" "Subnet-01-RT" {
  vpc_id = aws_vpc.VPC-01.id

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet access
    gateway_id = aws_internet_gateway.VPC-01-IGW.id
  }

  tags = {
    Name = "Subnet-01-RT"
  }
}

resource "aws_route_table_association" "Subnet-01-RT" {
  subnet_id      = aws_subnet.VPC-01-Subnet-01.id
  route_table_id = aws_route_table.Subnet-01-RT.id
}


resource "aws_route_table" "Subnet-02-RT" {
  vpc_id = aws_vpc.VPC-01.id

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet access
    nat_gateway_id         = aws_nat_gateway.VPC-01-NGW.id
  }

  tags = {
    Name = "Subnet-02-RT"
  }
}

resource "aws_route_table_association" "Subnet-02-RT" {
  subnet_id      = aws_subnet.VPC-01-Subnet-02.id
  route_table_id = aws_route_table.Subnet-02-RT.id
}