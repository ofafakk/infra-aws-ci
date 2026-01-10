terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-ofafakk-2026" # <--- SEU BUCKET AQUI
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 1. Networking (Descobrindo a rede padrão da AWS) ---
# O Load Balancer precisa de pelo menos 2 subnets em zonas diferentes para funcionar
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- 2. Segurança ---
resource "aws_security_group" "alb_sg" {
  name        = "alb_security_group"
  description = "Libera HTTP para o mundo"

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

resource "aws_key_pair" "minha_chave" {
  key_name   = "chave-devops-lb"
  public_key = file("chave-devops.pub")
}

# --- 3. Os Servidores (Compute) ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "meu_servidor" {
  count         = var.quantidade_de_servidores
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.tamanho_da_instancia
  key_name      = aws_key_pair.minha_chave.key_name
  
  # Usamos o mesmo Security Group do LB para facilitar hoje
  vpc_security_group_ids = [aws_security_group.alb_sg.id]
  
  user_data = file("user_data.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "${var.nome_do_projeto}-${count.index}"
  }
}

# --- 4. O Balanceador de Carga (ALB) ---
resource "aws_lb" "meu_load_balancer" {
  name               = "meu-alb-devops"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids # Coloca o LB em todas as subnets
}

# Target Group: Onde os servidores serão registrados
resource "aws_lb_target_group" "grupo_alvo" {
  name     = "meu-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  
  health_check {
    path = "/"
    matcher = "200"
  }
}

# Listener: Ouve a porta 80 do LB e manda para o Target Group
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.meu_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grupo_alvo.arn
  }
}

# A Cola: Gruda as instâncias criadas no Target Group
resource "aws_lb_target_group_attachment" "anexar_servidores" {
  count            = var.quantidade_de_servidores
  target_group_arn = aws_lb_target_group.grupo_alvo.arn
  target_id        = aws_instance.meu_servidor[count.index].id # Pega o ID de cada servidor
  port             = 80
}

# --- 5. Output Final ---
output "dns_load_balancer" {
  value       = aws_lb.meu_load_balancer.dns_name
  description = "Acesse o site por aqui (URL unica)"
}