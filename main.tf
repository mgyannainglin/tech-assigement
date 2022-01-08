provider "aws" {
  region = var.region
}
#create vpc
resource "aws_vpc" "assigement-vpc" {
  cidr_block = var.cidr_block
  tags = {
    "Name" = "aws-assigement"
  }

}
#create public subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.assigement-vpc.id
  cidr_block = var.public_subnet
  availability_zone = "ap-southeast-1a"
  tags = {
    "Name" = "dmz"
  }
}
#create private subnet
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.assigement-vpc.id
  cidr_block = var.private_subnet
  availability_zone = "ap-southeast-1a"
  tags = {
    "Name" = "app"
  }
}
#create extra subnet for lb
resource "aws_subnet" "lb_bk_subnet" {
  vpc_id = aws_vpc.assigement-vpc.id
  cidr_block = var.default_subnet
  availability_zone = "ap-southeast-1c"
  tags = {
    "Name" = "lb_bk_subnet"
  }
}
#create the internet gateway
resource "aws_internet_gateway" "igw_01" {
vpc_id = aws_vpc.assigement-vpc.id
tags = {
  "Name" = "igw_01"
}


}
#create the default route for public subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.assigement-vpc.id
      route  {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw_01.id
  }
  tags = {
    "Name" = "public_route_table"
  }
}
#create the default route for lb-bk subnet
resource "aws_route_table" "lb_bk_route_table" {
  vpc_id = aws_vpc.assigement-vpc.id
      route  {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw_01.id
  }
  tags = {
    "Name" = "lb_bk_route_table"
  }
}
#create the local route for private subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.assigement-vpc.id
  tags = {
  "Name" = "private_route_table"
  }
}
#associate the default route with public subnet
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public_route_table.id
}
#associate the default route with lb-bk subnet
resource "aws_route_table_association" "lb_bk_route_table_association" {
  subnet_id = aws_subnet.lb_bk_subnet.id
  route_table_id = aws_route_table.lb_bk_route_table.id
}
#associate the route table with private subnet
resource "aws_route_table_association" "private_route_table_association" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.private_route_table.id
}
#create the security group public
resource "aws_security_group" "allow_http_from_lb" {
  name = "http_sg"
  description = "Allow port 80 for inbound traffic"
  vpc_id = aws_vpc.assigement-vpc.id
  ingress {
    description = "http_from_public"
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
   tags = {
     Name = "allow_http_rule-for-public_subnet"
   }
}
#create security group for private
resource "aws_security_group" "allow_private2public" {
  name = "private2public_sg"
  description = "Allow port 80 for private2public"
  vpc_id = aws_vpc.assigement-vpc.id
  ingress {
    description = "private2public"
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["10.0.1.0/24"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
   tags = {
     Name = "allow_private2public_subnet"
   }
}
#create the ec2_instances
resource "aws_instance" "app_instance" {
  ami           = "ami-0dc5785603ad4ff54"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private.id
  count = 2
  security_groups = [aws_security_group.allow_private2public.id]
  user_data= <<EOF
    #cloud-config
    cloud_final_modules:
    - [users-groups,always]
    users:
      - name: ynl
        groups: [ wheel ]
        sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
        shell: /bin/bash
        ssh-authorized-keys:
        - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCzqsc6rNreEAm/i++gD3WIdzloHD4EoBVGFGVu2vEYIjoM2i2TxQvxUFQTdNso7iB4+2qVOYTP2vm6mDEs7zLS8R0n5Wp0Ur1GHYt6rK7CH39m4cShy/FoMs1du4lBmSgWCMR24qRggfHseI8iqVogjHjV2hw5uuqIM+R+hxe0ERUee8aMqFmePAiZNwBAhdijidSlfPhCEyOtDWUhA5iL1G5nfLBktpZIfvGyIdejIWGrkINRokvNHCQRkKTP62n/23ZnYrTli7YGy329K+5C7NV5l4lUTGq7p4k1RmZEayYSUxQGoDrrij9Lub/oitBOSG4JtRP/XfavBN8Tx7MT ynl@pop-os
EOF
tags = {
  "Name" = "app${count.index}"
  #"Name" = "app"
}
}
#create the loadbalancer
resource "aws_alb" "app-lb01" {
  name = "app-lb01"
  internal = false
  subnets = [aws_subnet.public.id,aws_subnet.lb_bk_subnet.id]
  security_groups = [aws_security_group.allow_http_from_lb.id]
  tags = {
    Name = "app-lb-01"
  }
  ip_address_type = "ipv4"
  load_balancer_type = "application"
}
#create the loadbalancer target group
resource "aws_lb_target_group" "lb_tg" {
  target_type = "instance"
  protocol = "HTTP"
  name = "lb-tg"
  port = "80"
  vpc_id = aws_vpc.assigement-vpc.id
     health_check {
   interval = 10
   path     = "/"
   protocol = "HTTP"
   timeout = 5
   healthy_threshold = 5
}
}
resource "aws_lb_target_group_attachment" "lb_tg_attach01" {
  target_group_arn = aws_lb_target_group.lb_tg.id
  target_id = "${element(aws_instance.app_instance.*.id, 0)}"
  port             = 80
}
resource "aws_lb_target_group_attachment" "lb_tg_attach02" {
  target_group_arn = aws_lb_target_group.lb_tg.id
  target_id = "${element(aws_instance.app_instance.*.id, 1)}"
  port             = 80
}
resource "aws_lb_listener" "app_lb_listner"{
  load_balancer_arn = aws_alb.app-lb01.arn
   default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg.arn
  }
  port = 80
  protocol = "HTTP"
}

