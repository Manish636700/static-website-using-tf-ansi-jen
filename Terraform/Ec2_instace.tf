provider "aws" {
 region=var.aws_region
}


# create vpc

resource "aws_vpc" "main_vpc" {
 cidr_block = "10.0.0.0/16"

tags = {
 Name = "main_vpc"
}
}

#Create subnet 
resource "aws_subnet" "main_subnet" {
 vpc_id = aws_vpc.main_vpc.id
 cidr_block = "10.0.1.0/24"
 availability_zone = "us-east-1a"

tags = { name= "main_subnet"}
}

#Create Internet Gateway

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}

#Create Route table

resource "aws_route_table" "man_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}

#Associate

resource "aws_route_table_association" "main_ass" {
  subnet_id = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.man_route_table.id
}

#Create security group

resource "aws_security_group" "all_sg"{
 name="all_sg"
 description = "Allow ALL"
 vpc_id = aws_vpc.main_vpc.id

 ingress {
  from_port=0
  to_port=65535
  protocol="tcp"
  cidr_blocks=["0.0.0.0/0"]
 }

 egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks=["0.0.0.0/0"]
 }	
}

resource "aws_key_pair" "manish_key" {
 key_name = var.key_name
 public_key=file(var.public_key_path)
}
resource "aws_instance" "ec2_instance" {
  ami = var.ami_id
  instance_type = var.instance_type
  key_name = aws_key_pair.manish_key.key_name
  subnet_id = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.all_sg.id]
  associate_public_ip_address = true
tags ={
  Name = "ManishTerraformEC2"
 }
}

