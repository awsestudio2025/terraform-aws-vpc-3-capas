# outputs.tf

# ============================================
# 1. ACCESO PÚBLICO (ALB & DNS)
# ============================================

output "application_load_balancer_dns_name" {
  description = "El nombre DNS (URL) del Application Load Balancer para acceder a la aplicación."
  # Asegúrate de que este nombre coincida con tu recurso ALB (ej. aws_lb.application_lb.dns_name)
  value       = aws_lb.application_lb.dns_name
}

output "alb_security_group_id" {
  description = "The ID of the ALB Security Group."
  # Se asume que el SG del ALB se llama 'aws_security_group.alb_sg'
  value       = aws_security_group.alb_sg.id
}

# ============================================
# 2. IDENTIFICADORES DE RED (Para otros módulos)
# ============================================

output "vpc_id" {
  description = "The ID of the VPC."
  # Utiliza el nombre de tu recurso VPC (ej. aws_vpc.three_tier_vpc)
  value       = aws_vpc.three_tier_vpc.id
}

output "public_subnet_ids" {
  description = "Lista de IDs de las subredes públicas (para el ALB y NAT Gateway)."
  # Usando el splat operator (*) para manejar todas las subredes públicas de forma escalable
  value       = aws_subnet.public.*.id 
}

output "app_private_subnet_ids" {
  description = "Lista de IDs de las subredes privadas de aplicación (para los servidores ASG)."
  value       = aws_subnet.app_private.*.id
}

output "db_private_subnet_ids" {
  description = "Lista de IDs de las subredes privadas de base de datos (para el RDS)."
  # Asumiendo que tienes subredes dedicadas para la capa de datos
  value       = aws_subnet.data_private.*.id 
}

# ============================================
# 3. CAPA DE DATOS (Información para conectar la aplicación)
# ============================================

output "rds_endpoint" {
  description = "El endpoint de la base de datos (URL) para la conexión de la aplicación."
  # Se asume que tu instancia RDS se llama 'aws_db_instance.app_db'
  value       = aws_db_instance.app_db.address
  sensitive   = true # Marca el output como sensible
}

output "rds_username" {
  description = "El nombre de usuario maestro del RDS."
  value       = aws_db_instance.app_db.username
  sensitive   = true
}