terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "men-jenkins-project-backend"
    key = "backend/tf-backend-jenkins.tfstate"      # terraform dosyasinin ".tfstate" dosyasini S3'e kaydetmek icin kullanilir
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "tags" {
  default = ["postgresql", "nodejs", "react"]
}

variable "user" {
  default = "edipnegiz"
}

variable "sec-gr" {
  default = [22, 5000, 3000, 5432]
}

resource "aws_instance" "managed_nodes" {
  ami = "ami-06640050dc3f556bb"
  count = 3
  instance_type = "t2.micro"
  key_name = "XXXXXXX"  # change with your pem file
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  iam_instance_profile = "jenkins-project-profile-${var.user}" # we created this with jenkins server
  tags = {
    Name = "ansible_${element(var.tags, count.index )}"
    stack = "ansible_project"
    environment = "development"
  }
}

resource "aws_security_group" "tf-sec-gr" {
  name = "project208-sec-gr"
  tags = {
    Name = "project208-sec-gr"
  }

dynamic "ingress" {
    for_each = var.sec-gr
content {
    from_port = ingress.value
    to_port = ingress.value
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
}
  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "react_ip" {
  value = "http://${aws_instance.managed_nodes[2].public_ip}:3000"
}

output "node_public_ip" {
  value = aws_instance.managed_nodes[1].public_ip
}

output "postgre_private_ip" {
  value = aws_instance.managed_nodes[0].private_ip
}