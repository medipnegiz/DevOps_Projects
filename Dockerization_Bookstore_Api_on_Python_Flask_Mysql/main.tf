terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "github" {
  token = "<TOKEN HERE>"  # dont forget
}

resource "github_repository" "githup-repo" {
  name        = "bookstore-repo"
  auto_init   = true
  description = "This Repository includes Docker files"
  visibility  = "private"
}

resource "github_branch_default" "github-branch" {
  branch     = "main"
  repository = github_repository.githup-repo.name
}

variable "files" {
  default = ["bookstore-api.py", "requirements.txt", "Dockerfile", "docker-compose.yml"]
}

resource "github_repository_file" "github-push" {
  for_each            = toset(var.files)
  file                = each.value
  content             = file(each.value)
  repository          = github_repository.githup-repo.name
  branch              = "main"
  commit_message      = "Managed by Terraform"
  overwrite_on_create = true
}

resource "aws_security_group" "bookstore-sec" {
  name        = "bookstore-sec-group"
  description = "Allow TLS inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bookstore-sec-group"
  }
}

resource "aws_instance" "bookstore_ec2" {
  ami             = "ami-0f9fc25dd2506cf6d"
  instance_type   = "t2.micro"
  key_name        = "<KEY HERE>"  # dont forget
  security_groups = [aws_security_group.bookstore-sec.name]
  user_data       = <<-EOF
            #! /bin/bash
            yum update -y
            amazon-linux-extras install docker -y
            yum install git -y
            systemctl start docker
            systemctl enable docker
            usermod -a -G docker ec2-user
            curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            mkdir -p /home/ec2-user/bookstore-api
            TOKEN="<TOKEN HERE>"  # dont forget
            FOLDER="https://$TOKEN@raw.githubusercontent.com/medipnegiz/bookstore-repo/main/"
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/app.py" -L "$FOLDER"bookstore-api.py
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/requirements.txt" -L "$FOLDER"requirements.txt
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/Dockerfile" -L "$FOLDER"Dockerfile
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/docker-compose.yml" -L "$FOLDER"docker-compose.yml
            cd /home/ec2-user/bookstore-api
            docker build -t medipnegiz/bookstore-api:latest .
            docker-compose up -d
            hostnamectl set-hostname DockerServer
            echo 'export PS1="\[\e[1;31m\]\u\[\e[33m\]@\h: \W:\[\e[34m\]\\$\[\e[m\]"' >> /home/ec2-user/.bashrc
            EOF
  tags = {
    "Name" = "Bookstore-instance"
  }
  depends_on = [
    github_repository_file.github-push
  ]
}