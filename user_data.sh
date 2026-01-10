#!/bin/bash
# 1. Atualizar o sistema
dnf update -y

# 2. Instalar o Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# 3. Dar permissão para o usuário padrão usar o Docker
usermod -aG docker ec2-user

# 4. Rodar um site pronto (Super Mario em HTML5 ou Nginx simples)
# Vamos usar o Nginx com uma mensagem personalizada
docker run -d -p 80:80 --name meu-site nginx

# 5. Criar uma página HTML personalizada dentro do container
echo "<h1>Fase Concluida!</h1><p>Este servidor se configurou sozinho via Terraform + Docker.</p>" > index.html
docker cp index.html meu-site:/usr/share/nginx/html/index.html