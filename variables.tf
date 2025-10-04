# variables.tf

# ============================================
# 1. VARIABLES GENERALES DEL ENTORNO
# ============================================

variable "project_name" {
  description = "Prefijo para nombrar todos los recursos (ej. 'ecommerce-dev')."
  type        = string
  default     = "mi-app-test" 
}

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura."
  type        = string
  default     = "us-east-1" # Define un valor por defecto (la región que estás usando)
}

# ============================================
# 2. CONFIGURACIÓN DE SEGURIDAD (SECURITY GROUPS)
# ============================================

# variable "alb_ingress_ports" {
#   description = "Puertos de entrada al ALB para el tráfico web (ej. HTTP y HTTPS)."
#   type        = list(number)
#   default     = [80, 443] # Los puertos que el ALB escucha desde Internet
# }

# variable "app_server_listen_port" {
#   description = "Puerto interno en el que escucha la aplicación en las instancias EC2 (Target Group)."
#   type        = number
#   default     = 8080 # Tu puerto actual en el TG y el SG
# }

# ============================================
# 3. CONFIGURACIÓN DEL AUTO SCALING GROUP (ASG)
# ============================================

variable "instance_ami_id_app" {
  description = "ID de la AMI (Imagen de máquina de Amazon) para las instancias EC2."
  type        = string
  # ID de ejemplo que usaste (Amazon Linux 2023)
  default     = "ami-052064a798f08f0d3" 
}

variable "instance_type_app" {
  description = "Tipo de instancia EC2 a usar (determina la capacidad)."
  type        = string
  default     = "t3.micro" # Tu tipo de instancia actual
}

variable "ssh_key_name" {
  description = "Nombre de la clave SSH existente en AWS para el acceso a las instancias."
  type        = string
  default     = "KeyPair-Ec2lab" # Tu nombre de KeyPair actual
}

variable "asg_desired_capacity" {
  description = "Número de instancias que el ASG debe mantener en funcionamiento."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Número máximo de instancias que el ASG puede escalar."
  type        = number
  default     = 4
}

# ==================================================
# 4. CONFIGURACION VARIABLES RDS ARCHIVO database.tf
# ==================================================

variable "instance_allocated_storage_data" {
  description = "Almacenamiento asignado."
  type        = number
  default     = 20
}

variable "instance_engine_data" {
  description = "Tipo de instancia EC2 a usar (determina la capacidad)."
  type        = string
  default     = "postgres" # Ejemplo: Podría ser mysql, mariadb, etc.
}

variable "instance_type_data" {
  description = "Tipo de instancia EC2 a usar (determina la capacidad)."
  type        = string
  default     = "db.t3.micro" # Tamaño pequeño para pruebas (Free Tier)
}

variable "instance_username_data" {
  description = "Tipo de instancia EC2 a usar (determina la capacidad)."
  type        = string
  default     = "appuser" # usuario RDP data
}

variable "instance_password_data" {
  description = "Tipo de instancia EC2 a usar (determina la capacidad)."
  type        = string
  default     = "PasswordSeguro123" # ¡USAR SECRETS MANAGER en producción!
}
