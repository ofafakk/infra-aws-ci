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

# 4. O Servidor (AGORA ESCALÁVEL)
resource "aws_instance" "meu_servidor" {
  # --- A MÁGICA DO LOOP ---
  count = var.quantidade_de_servidores 
  # O Terraform vai ler o número 3 e rodar esse bloco 3 vezes
  # ------------------------

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.tamanho_da_instancia # Usando a variável

  key_name               = aws_key_pair.minha_chave.key_name
  vpc_security_group_ids = [aws_security_group.firewall.id]
  
  user_data = file("user_data.sh")
  user_data_replace_on_change = true 

  tags = {
    # count.index é o número atual do loop (0, 1, 2...)
    # Os nomes ficarão: Servidor-0, Servidor-1, Servidor-2
    Name = "${var.nome_do_projeto}-${count.index}"
  }
}

# 5. Output dos IPs (PRECISA MUDAR)
# Como agora são vários servidores, o output muda de um valor único para uma lista [*]
output "ips_publicos" {
  value       = aws_instance.meu_servidor[*].public_ip
  description = "Lista dos IPs Publicos dos servidores"
  }