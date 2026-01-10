variable "nome_do_projeto" {
  description = "Nome base para as tags dos recursos"
  type        = string
  default     = "Projeto-DevOps-Escalavel"
}

variable "tamanho_da_instancia" {
  description = "Tamanho da maquina EC2 (t3.micro eh free tier)"
  type        = string
  default     = "t3.micro"
}

variable "quantidade_de_servidores" {
  description = "Quantas maquinas vamos subir?"
  type        = number
  default     = 3  # <--- VAMOS SUBIR 3 SERVIDORES DE UMA VEZ!
}