terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Enviar sua Chave Pública para a AWS
resource "aws_key_pair" "minha_chave" {
  key_name   = "chave-devops-aws"
  public_key = file("chave-devops.pub")
}

# 2. Criar o Porteiro (Security Group/Firewall)
resource "aws_security_group" "firewall" {
  name        = "libera_ssh_http"
  description = "Libera porta 22 e 80"

  # Entrada: SSH (22) liberado para todo mundo (0.0.0.0/0)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Entrada: HTTP (80) liberado para todo mundo
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saída: Liberada para qualquer lugar (o servidor precisa baixar atualizações)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Buscar o Linux mais recente
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# 4. Criar o Servidor
resource "aws_instance" "meu_servidor" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  
  # AQUI ESTÁ O SEGREDO: Conectando a chave e o firewall
  key_name               = aws_key_pair.minha_chave.key_name
  vpc_security_group_ids = [aws_security_group.firewall.id]

  tags = {
    Name = "Servidor-Com-Acesso"
  }
}

# 5. Output: Mostrar o IP no final
output "ip_publico" {
  value = aws_instance.meu_servidor.public_ip
  description = "O IP Publico do servidor para conectar"
}