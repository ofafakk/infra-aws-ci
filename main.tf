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

# --- 1. Networking e Security ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb_security_group_asg" # Mudei o nome para evitar conflito
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
  key_name   = "chave-devops-asg" # Mudei o nome
  public_key = file("chave-devops.pub")
}

# --- 2. O Modelo da Máquina (Launch Template) ---
# Aqui definimos COMO a máquina deve ser, mas não criamos nenhuma ainda.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "modelo_servidor" {
  name_prefix   = "modelo-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.tamanho_da_instancia
  key_name      = aws_key_pair.minha_chave.key_name

  vpc_security_group_ids = [aws_security_group.alb_sg.id]

  # IMPORTANTE: No Launch Template, o script precisa ser base64
  user_data = filebase64("user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Servidor-AutoScaling"
    }
  }
}

# --- 3. O Gerenciador de Escala (Auto Scaling Group) ---
resource "aws_autoscaling_group" "grupo_escalavel" {
  # Configurações de Quantidade
  desired_capacity    = 2  # Começa com 2
  max_size            = 5  # Pode crescer até 5
  min_size            = 1  # Nunca ter menos de 1

  # Onde as máquinas vão morar (Subnets)
  vpc_zone_identifier = data.aws_subnets.default.ids

  # Conexão com o Load Balancer (Ele se registra sozinho aqui)
  target_group_arns = [aws_lb_target_group.grupo_alvo.arn]

  # Qual modelo usar?
  launch_template {
    id      = aws_launch_template.modelo_servidor.id
    version = "$Latest"
  }
  
  # Se mudar o modelo, ele troca as máquinas antigas pelas novas
  instance_refresh {
    strategy = "Rolling"
  }
}

# --- 4. Load Balancer (Praticamente igual) ---
resource "aws_lb" "meu_load_balancer" {
  name               = "meu-alb-asg"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "grupo_alvo" {
  name     = "target-group-asg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  
  health_check {
    path = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.meu_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grupo_alvo.arn
  }
}

# --- 5. Output ---
output "dns_load_balancer" {
  value = aws_lb.meu_load_balancer.dns_name
}