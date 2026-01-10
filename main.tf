terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # --- CORREÇÃO: O backend agora está DENTRO do bloco terraform ---
  backend "s3" {
    bucket = "terraform-state-ofafakk-2026" # <--- TROQUE PELO NOME DO SEU BUCKET
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
  # -------------------------------------------------------------
}

provider "aws" {
  region = "us-east-1"
}

# 1. Enviar sua Chave Pública
resource "aws_key_pair" "minha_chave" {
  key_name   = "chave-devops-aws"
  public_key = file("chave-devops.pub")
}

# 2. Firewall (Security Group)
resource "aws_security_group" "firewall" {
  name        = "libera_ssh_http"
  description = "Libera porta 22 e 80"

  # Porta 22 (SSH) - Aberta para todos (Para facilitar o teste)
  # Em produção, troque "0.0.0.0/0" pelo seu IP "/32"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Porta 80 (HTTP) - Aberta para o mundo (Site)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saída liberada
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Buscar Linux recente
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 4. O Servidor
resource "aws_instance" "meu_servidor" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro" # Ajustado para t3 (Free Tier atual)

  key_name               = aws_key_pair.minha_chave.key_name
  vpc_security_group_ids = [aws_security_group.firewall.id]

  tags = {
    Name = "Servidor-Automático-GitHub-Actions"
  }
}

# 5. Output do IP
output "ip_publico" {
  value       = aws_instance.meu_servidor.public_ip
  description = "O IP Publico do servidor"
}