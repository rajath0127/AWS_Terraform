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
                sudo bash -c "echo '<h1>Server Details:</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>' > /var/www/html/index.html"
                sudo systemctl start apache2
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
                sudo bash -c "echo '<h1>Server Details:</h1><p><strong>Hostname:</strong> $(hostname)</p><p><strong>IP Address:</strong> $(hostname -I)</p>' > /var/www/html/index.html"
                sudo systemctl start apache2
                EOF

  tags = {
     Name = "VPC-02-EC2-01"
  }
}

output "VPC-01-EC2-01-Public-IP" {
  value = aws_instance.VPC-01-EC2-01.public_ip
}

output "VPC-02-EC2-01-Public-IP" {
  value = aws_instance.VPC-02-EC2-01.public_ip
}

resource "aws_ec2_transit_gateway_route_table" "Transit-GW-RT" {
  transit_gateway_id = aws_ec2_transit_gateway.VPC-Transit-GW.id
  tags = {
    Name = "VPC-Transit-GW-RT"
  }
}

# Attach VPC 1 to the Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "VPC-01-TGA" {
  transit_gateway_id = aws_ec2_transit_gateway.VPC-Transit-GW.id
  vpc_id             = aws_vpc.VPC-01.id
  subnet_ids         = [aws_subnet.VPC-01-Subnet-01.id]

  tags = {
    Name = "VPC-01-TGA"
  }
}

# Attach VPC 2 to the Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "VPC-02-TGA" {
  transit_gateway_id = aws_ec2_transit_gateway.VPC-Transit-GW.id
  vpc_id             = aws_vpc.VPC-02.id
  subnet_ids         = [aws_subnet.VPC-02-Subnet-01.id]
  
  tags = {
    Name = "VPC-02-TGA"
  }
}

resource "aws_route_table" "VPC-01-Subnet-01-RT" {
  vpc_id = aws_vpc.VPC-01.id

  route {
    cidr_block = "0.0.0.0/0"  # Route for internet access
    gateway_id = aws_internet_gateway.VPC-01-IGW.id
  }

  route {
    cidr_block = var.vpc_cidr[1]  # Route for VPC-02
    transit_gateway_id = aws_ec2_transit_gateway.VPC-Transit-GW.id
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
    transit_gateway_id = aws_ec2_transit_gateway.VPC-Transit-GW.id
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



resource "aws_ec2_transit_gateway" "VPC-Transit-GW" {
  description         = "Transit Gateway Object"
  amazon_side_asn     = 64512 # ASN for the TGW (default: 64512)
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  #default_route_table_propagation = "enable"
  tags = {
    Name = "VPC-Transit-GW"
  }
}



# Add routes to the Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route" "route-to-VPC-01" {
  destination_cidr_block         = var.vpc_cidr[0]
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Transit-GW-RT.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.VPC-01-TGA.id
}

resource "aws_ec2_transit_gateway_route" "route-to-VPC-02" {
  destination_cidr_block         = var.vpc_cidr[1]
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Transit-GW-RT.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.VPC-02-TGA.id
}