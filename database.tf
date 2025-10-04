#   TF con IaC para el despliegue de:
#        -Security Groups para RDS
#        -Grupo de Subredes para RDS
#        -Instancias de RDS

#1. GRUPOS DE SEGURIDAD (SECURITY GROUPS - SGs)
# ==============================================================================
# 1.1. SG para RDS (Capa de Datos)
# Solo permite tráfico de la Capa de Aplicación.
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.three_tier_vpc.id
  name   = "rds-sg"

  # INGRESO: SOLO permite tráfico desde las instancias de aplicación (EC2)
  ingress {
    from_port       = 5432 # Puerto de PostgreSQL (ejemplo)
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Referencia al SG de la App
    description     = "Permitir trafico solo desde la capa de aplicacion"
  }

  # EGRESO: No se necesita salida, pero se permite tráfico interno a la misma red (práctica común).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.three_tier_vpc.cidr_block}"]
  }

  tags = {
    Name = "RDS_SG"
  }
}

# 2. RECURSOS DE DATOS (AMAZON RDS)
# ==============================================================================

# Grupo de Subredes para RDS (Es obligatorio para que RDS sepa dónde desplegarse)
resource "aws_db_subnet_group" "rds_subnet_group" {
  # Incluye ambas subredes de datos para HA (Multi-AZ)
  subnet_ids = [aws_subnet.data_private_a.id, aws_subnet.data_private_b.id]
  tags = {
    Name = "rds-data-subnet-group"
  }
}

# Instancia de RDS (Base de Datos)
resource "aws_db_instance" "app_db" {
  identifier           = "mi-app-db"
  allocated_storage    = var.instance_allocated_storage_data
  engine               = var.instance_engine_data
  instance_class       = var.instance_type_data
  username             = var.instance_username_data
  password             = var.instance_password_data
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id] # El firewall de datos
  skip_final_snapshot  = true # Para que se destruya rápido al hacer 'terraform destroy'
}

# Modificar el Output para incluir el endpoint del RDS
# output "rds_endpoint" {
#   description = "El endpoint de la base de datos RDS para la conexión de la app"
#   value       = aws_db_instance.app_db.address
# }
