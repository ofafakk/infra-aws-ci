terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-ofafakk-2026" # <--- CONFIRME SEU BUCKET
    key    = "terraform-rds.tfstate"       # Mudei o nome do arquivo para organizar
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 1. Rede Básica (VPC) ---
resource "aws_vpc" "vpc_dados" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "VPC-Database-Lab" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_dados.id
}

# Criamos 2 subnets porque o RDS exige Alta Disponibilidade (mínimo 2 zonas)
resource "aws_subnet" "sub_a" {
  vpc_id            = aws_vpc.vpc_dados.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "Subnet-A" }
}

resource "aws_subnet" "sub_b" {
  vpc_id            = aws_vpc.vpc_dados.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "Subnet-B" }
}

# --- 2. Preparação para o Banco (DB Subnet Group) ---
# Isso agrupa as subnets onde o banco pode "morar"
resource "aws_db_subnet_group" "grupo_banco" {
  name       = "meu-grupo-de-banco"
  subnet_ids = [aws_subnet.sub_a.id, aws_subnet.sub_b.id]

  tags = {
    Name = "Grupo de Subnets do MySQL"
  }
}

# --- 3. Segurança (Quem pode acessar?) ---
resource "aws_security_group" "sg_banco" {
  name        = "sg_mysql"
  description = "Permite acesso ao MySQL"
  vpc_id      = aws_vpc.vpc_dados.id

  # CUIDADO: Em produção, nunca coloque 0.0.0.0/0 na porta do banco!
  # Estamos fazendo isso apenas para teste de laboratório hoje.
  ingress {
    from_port   = 3306
    to_port     = 3306
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

# --- 4. O Banco de Dados (RDS) ---
resource "aws_db_instance" "meu_mysql" {
  allocated_storage    = 10             # 10 GB de disco (Free Tier)
  db_name              = "bancofinanceiro" # Nome do banco interno
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"  # Tipo da máquina (Free Tier elegível)
  
  # Credenciais (Em prod, usaríamos Variáveis ou Secrets Manager)
  username             = "admin"
  password             = "SenhaSuperSecreta123" 
  
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true           # IMPORTANTE: Para destruir rápido e não cobrar snapshot
  publicly_accessible  = true           # Para podermos testar conexão de fora (Lab only)
  
  vpc_security_group_ids = [aws_security_group.sg_banco.id]
  db_subnet_group_name   = aws_db_subnet_group.grupo_banco.name
  
  tags = {
    Name = "Meu-Primeiro-RDS"
  }
}

# --- 5. Output ---
output "endereco_do_banco" {
  value = aws_db_instance.meu_mysql.endpoint
  description = "Use este endereço para conectar no MySQL Workbench ou DBeaver"
}