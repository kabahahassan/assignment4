terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Create a VPC
resource "aws_vpc" "tr_VPC" {
  cidr_block = "10.88.0.0/16"
  tags = {
    Name = "tr-VPC"
  }
}

#create public subnet
resource "aws_subnet" "tr_wordpress_public" {
  vpc_id                  = aws_vpc.tr_VPC.id
  cidr_block              = "10.88.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "tr_wordpress_public"
  }
}

#create private subnet
resource "aws_subnet" "tr_wordpress_private" {
  vpc_id     = aws_vpc.tr_VPC.id
  cidr_block = "10.88.2.0/24"

  tags = {
    Name = "tr_wordpress_private"
  }
}

#create internet gateway
resource "aws_internet_gateway" "tr_internet_gateway" {
  vpc_id = aws_vpc.tr_VPC.id

  tags = {
    Name = "tr_internet_gateway"
  }
}

#create elastic IP
resource "aws_eip" "tr_elastic_IP" {
  vpc = true
}

# create NAT gateway
resource "aws_nat_gateway" "tr_wordpress_nat" {
  allocation_id = aws_eip.tr_elastic_IP.id
  subnet_id     = aws_subnet.tr_wordpress_public.id

  tags = {
    Name = "tr_wordpress_nat"
  }
}

# create public route table
resource "aws_route_table" "tr_rt_wordpress_vpc_public" {
  vpc_id = aws_vpc.tr_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tr_internet_gateway.id
  }

  tags = {
    Name = "tr_rt_wordpress_vpc_public"
  }
}

# create private route table
resource "aws_route_table" "tr_rt_wordpress_vpc_private" {
  vpc_id = aws_vpc.tr_VPC.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tr_wordpress_nat.id
  }

  tags = {
    Name = "tr_rt_wordpress_vpc_private"
  }
}

# route table association
resource "aws_route_table_association" "tr_associate_public" {
  subnet_id      = aws_subnet.tr_wordpress_public.id
  route_table_id = aws_route_table.tr_rt_wordpress_vpc_public.id
}

# route table association
resource "aws_route_table_association" "tr_associate_private" {
  subnet_id      = aws_subnet.tr_wordpress_private.id
  route_table_id = aws_route_table.tr_rt_wordpress_vpc_private.id
}

# create security group with rules for wordpress server
resource "aws_security_group" "tr_wordpress_sg" {
  name        = "allow_wordpress_traffic"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.tr_VPC.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "All networks allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "All networks allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    "Name" = "rt_wordpress_sg"
  }

}

# create security group with rules for SQL server
resource "aws_security_group" "tr_MySQL_sg" {
  name        = "allow_MySQL_traffic"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.tr_VPC.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "All networks allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "All networks allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    "Name" = "rt_wordpress_sg"
  }

}

# create wordpress interface
resource "aws_network_interface" "tr_interface_wordpress" {
  subnet_id       = aws_subnet.tr_wordpress_public.id
  private_ips     = ["10.88.1.10"]
  security_groups = [aws_security_group.tr_wordpress_sg.id]

}

# create MySQL interface
resource "aws_network_interface" "tr_interface_MySQL" {
  subnet_id       = aws_subnet.tr_wordpress_private.id
  private_ips     = ["10.88.2.10"]
  security_groups = [aws_security_group.tr_MySQL_sg.id]

}

# create wordpress instance
resource "aws_instance" "tr_wordpress_insrance" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  key_name      = "hassan-key"

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install docker.io -y
                sudo docker run -itd -e WORDPRESS_DB_HOST=10.88.2.10 -e WORDPRESS_DB_USER=wordpress -e WORDPRESS_DB_PASSWORD=wordpress -e WORDPRESS_DB_NAME=wordpress -v wp_site:/var/www/html -p 8080:80 wordpress
                
                
                EOF

  tags = {
    Name = "tr_wordpress_insrance"
  }
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.tr_interface_wordpress.id
  }
}

# create MySQL instance
resource "aws_instance" "tr_MySQL_insrance" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  key_name      = "hassan-key"

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install docker.io -y
                sudo docker run -itd -e MYSQL_ROOT_PASSWORD=wordpress -e MYSQL_DATABASE=wordpress -e MYSQL_USER=wordpress -e MYSQL_PASSWORD=wordpress -v wordpress_db:/var/lib/mysql -p 3306:3306 mysql
                
                
                EOF

  tags = {
    Name = "tr_MySQL_insrance"
  }
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.tr_interface_MySQL.id
  }
}

