terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-ofafakk-2026" # <--- SEU BUCKET (confirme se está certo)
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. NETWORKING (A Base)
# ==========================================
resource "aws_vpc" "minha_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "VPC-Production" }
}

resource "aws_internet_gateway" "meu_gateway" {
  vpc_id = aws_vpc.minha_vpc.id
}

resource "aws_subnet" "publica_a" {
  vpc_id                  = aws_vpc.minha_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "publica_b" {
  vpc_id                  = aws_vpc.minha_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "rotas_publicas" {
  vpc_id = aws_vpc.minha_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.meu_gateway.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.publica_a.id
  route_table_id = aws_route_table.rotas_publicas.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.publica_b.id
  route_table_id = aws_route_table.rotas_publicas.id
}

# ==========================================
# 2. SEGURANÇA (Security Groups)
# ==========================================
resource "aws_security_group" "autoscaling_sg" {
  name        = "autoscaling_sg_custom"
  description = "Security Group para o ASG na VPC Customizada"
  vpc_id      = aws_vpc.minha_vpc.id # <--- IMPORTANTE: Define onde ele mora

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

# ==========================================
# 3. COMPUTE (Launch Template + ASG)
# ==========================================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_launch_template" "modelo_v2" {
  name_prefix   = "modelo-vpc-custom-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.tamanho_da_instancia
  
  # Como estamos na VPC nova, o SG tem que ser o da VPC nova
  vpc_security_group_ids = [aws_security_group.autoscaling_sg.id]

  user_data = filebase64("user_data.sh")
}

resource "aws_autoscaling_group" "asg_v2" {
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  
  # AQUI ESTA A MAGICA: Mandamos criar nas NOSSAS subnets, não nas da Amazon
  vpc_zone_identifier = [aws_subnet.publica_a.id, aws_subnet.publica_b.id]
  
  target_group_arns   = [aws_lb_target_group.tg_v2.arn]

  launch_template {
    id      = aws_launch_template.modelo_v2.id
    version = "$Latest"
  }
}

# ==========================================
# 4. LOAD BALANCER (ALB)
# ==========================================
resource "aws_lb" "alb_v2" {
  name               = "alb-vpc-custom"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.autoscaling_sg.id]
  
  # O LB também precisa morar nas subnets novas
  subnets            = [aws_subnet.publica_a.id, aws_subnet.publica_b.id]
}

resource "aws_lb_target_group" "tg_v2" {
  name     = "tg-vpc-custom"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.minha_vpc.id # <--- O TG precisa saber a qual VPC pertence
  
  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "listener_v2" {
  load_balancer_arn = aws_lb.alb_v2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_v2.arn
  }
}

# ==========================================
# 5. OUTPUTS
# ==========================================
output "dns_load_balancer" {
  value = aws_lb.alb_v2.dns_name
}