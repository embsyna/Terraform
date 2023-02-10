# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "AKIA3BWTH53WR2KHAUV3"
  secret_key = "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"
}

# Create VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "utc-vpc" 
  cidr = "10.0.0.0/16" 
  
 

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true

  tags = {
    name = "utc-vpc"
    Environment = "dev"
    team = "config management"
  }
}

resource "aws_internet_gateway_attachment" "utc" {
  internet_gateway_id = aws_internet_gateway.utc.id
  vpc_id              = module.vpc.vpc_id
}

# resource "aws_vpc" "utc" {
#   cidr_block = "10.1.0.0/16"
# }

resource "aws_internet_gateway" "utc" {}

# Creating Multiple Security Groups

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow inbound from everywhere"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }



  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb_sg"
    Environment = "dev"
    team = "config management"
  }
}

resource "aws_security_group" "bation_host_sg" {
  name        = "bation_host_sg"
  description = "Allow inbound my ip to 22"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "ssh protocol"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["73.44.11.146/32"]
  }
  
 
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "bation_host_sg"
  }
}

resource "aws_security_group" "app_server_sg" {
  name        = "app_server_sg"
  description = "Allow inbound from alb to 80 and allows inbound from bastion to 22"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "alb to 80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.alb_sg.id}"]
  }
  
   ingress {
    description      = "bastion to 22"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.bation_host_sg.id}"]
  }
 
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "app_server_sg"
  }
}

resource "aws_security_group" "database_sg" {
  name        = "database_sg"
  description = "Allow inbound from aps-server sg to 3306"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "aps-server sg to 3306"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.app_server_sg.id}"]
  }
  
 
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "database_sg"
  }
}

#  resource "aws_instance" "BASTION" {
#   ami           = "ami-0aa7d40eeae50c9a9"
#   instance_type = "t2.micro"
#   subnet_id = "subnet-0b25a71792e78fcd9"
#   security_groups = ["${aws_security_group.bation_host_sg.id}" ]
#   key_name = "utc-key"


#   tags = {
#     Name = "bastionhost"
#     }
# } 



module "bastion" {
  source            = "github.com/jetbrains-infra/terraform-aws-bastion-host"
  subnet_id         = "10.0.1.0/24"
  ssh_key           = "utc-key"
  internal_networks = module.vpc.private_subnets
  project           = "myProject"
}

#key_name = "utc-key"

# 7. Create a Network Interface

# resource "aws_network_interface" "utc-web-server" {
#   subnet_id       = subnet-0b25a71792e78fcd9
#   private_ips     = ["10.0.1.0"]
#   security_groups = ["${aws_security_group.app_server_sg.id}"]

# }


# resource "aws_instance" "web-server-instance" {
#     ami = "ami-0aa7d40eeae50c9a9"
#     instance_type = "t2.micro"
#     availability_zone = "us-east-1a"
#     key_name = "utc-key"
#     vpc_security_group_ids = ["${aws_security_group.app_server_sg.id}"]

#     network_interface {
#          device_index = 0
#         network_interface_id = aws_network_interface.utc-web-server.id
#       }

#     user_data = <<-EOF
#                 #!/bin/bash
#                 sudo yum update -y
#                 sudo yum install -y httpd.x86_64
#                 sudo systemctl start httpd.service
#                 sudo systemctl enable httpd.service
#                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
#                 EOF

#     tags = {
#         Name: "appserver-1a"
#         env: "dev"
#         team = "config-management"
#     }            

# }

# resource "aws_instance" "web-server-instance2" {
#     ami = "ami-007868005aea67c54"
#     instance_type = "t2.micro"
#     availability_zone = "us-east-1b"
#     key_name = "utc-key"
#     vpc_security_group_ids = ["${aws_security_group.app_server_sg.id}"]

#     user_data = <<-EOF
#                 #!/bin/bash
#                 sudo yum update -y
#                 sudo yum install -y httpd.x86_64
#                 sudo systemctl start httpd.service
#                 sudo systemctl enable httpd.service
#                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
#                 EOF

#     tags = {
#         Name: "appserver-1a"
#         env: "dev"
#         team = "config-management"
#     } 

# }