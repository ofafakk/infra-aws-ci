terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-ofafakk-2026" # <--- SEU BUCKET
    key    = "terraform-monitoramento.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# ==========================================
# 1. O MENSAGEIRO (SNS - Simple Notification Service)
# ==========================================
resource "aws_sns_topic" "alerta_cpu" {
  name = "alerta-cpu-alta"
}

resource "aws_sns_topic_subscription" "email_usuario" {
  topic_arn = aws_sns_topic.alerta_cpu.arn
  protocol  = "email"
  endpoint  = "fabriciobotelho35@gmail.com" # <--- TROQUE PELO SEU EMAIL REAL
}

# ==========================================
# 2. O VIGIA (CloudWatch Alarm)
# ==========================================
resource "aws_cloudwatch_metric_alarm" "cpu_alta" {
  alarm_name          = "cpu-explodindo"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60  # Verifica a cada 60 segundos
  statistic           = "Average"
  threshold           = 50  # Dispara se passar de 50% de uso
  alarm_description   = "Esse alarme dispara quando a CPU passa de 50%"
  
  # O que fazer quando disparar? Chamar o tópico SNS (que manda o email)
  alarm_actions       = [aws_sns_topic.alerta_cpu.arn]
  
  # Precisamos dizer QUAL instância vigiar. Vamos apontar para a que criaremos abaixo.
  dimensions = {
    InstanceId = aws_instance.servidor_teste.id
  }
}

# ==========================================
# 3. A VÍTIMA (Servidor EC2)
# ==========================================
resource "aws_instance" "servidor_teste" {
  ami           = "ami-04b4f1a9cf54c11d0" # Ubuntu 24.04 (us-east-1)
  instance_type = "t2.micro"

  tags = {
    Name = "Servidor-Monitorado"
  }

  # Script para instalar o 'stress' (ferramenta para gerar caos)
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y stress
              EOF
}

output "instancia_id" {
  value = aws_instance.servidor_teste.id
}