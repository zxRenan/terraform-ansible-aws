
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.22.0" # Versão atualizada do provedor AWS
    }
  }
}

provider "aws" {
  region     = var.aws_region
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "minha-vpc"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.aws_subnet
  availability_zone = "us-east-1a"

  tags = {
    Name = "minha-subnet"
  }
}

resource "aws_security_group" "security_group" {
  name   = "security_group"
  vpc_id = aws_vpc.vpc.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "meu-ig"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "minha-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "chave-tf"
  public_key = file("./key-pair/key-tf.pub")
  }

resource "aws_instance" "web" {
  ami           = "ami-0fc5d935ebf8bc3bc"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet.id
  associate_public_ip_address = true
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.security_group.id]

  tags = {
    Name = "minha-ec2"
  }
  
  provisioner "file" {
    source      = "ansible"  # Caminho local do arquivo
    destination = "/home/ubuntu/ansible"  # Caminho na instância EC2 onde o arquivo será copiado

    connection {
      type        = "ssh"
      user        = "ubuntu"  # Usuário SSH da instância (pode variar dependendo da AMI)
      private_key = file("./key-pair/key-tf")
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt-get install -y ansible",
      "ansible-playbook --connection=local ansible/playbook.yaml"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"  # Usuário SSH da instância (pode variar dependendo da AMI)
      private_key = file("./key-pair/key-tf")
      host        = self.public_ip
    }
  }
}

output "ip_ec2" {
  value = aws_instance.web.public_ip
}