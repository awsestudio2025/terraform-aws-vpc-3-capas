data "aws_availability_zones" "available" {
  state = "available"
}
# 1. EL CONTENEDOR PRINCIPAL: VPC
# ------------------------------
resource "aws_vpc" "three_tier_vpc" {
  cidr_block           = "10.0.0.0/16" # Rango total de IPs para toda nuestra red (65,536 direcciones).
  enable_dns_support   = true          # Permite resoluciones DNS dentro de la VPC.
  enable_dns_hostnames = true          # Asigna nombres DNS a las instancias EC2.
  tags = {
    Name = "three-tier-vpc"
  }
}

# 2. PUERTA DE ENLACE A INTERNET (IGW)
# -----------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.three_tier_vpc.id # Asocia este IGW a la VPC que acabamos de crear.
  tags = {
    Name = "main-igw"
  }
}

# 3. SUBREDES (6 Subredes para 3 Capas x 2 AZs)
# ==============================================================================

# 3.1. CAPA PÚBLICA (Web/ALB) - Necesita ser accesible desde Internet.
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.three_tier_vpc.id
  cidr_block              = "10.0.1.0/24" # Rango de 256 IPs para AZ-A
  availability_zone       = data.aws_availability_zones.available.names[0] # Primera AZ disponible
  map_public_ip_on_launch = true # Importante: Asigna IPs públicas a los recursos lanzados aquí
  tags = {
    Name = "Public-A"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.three_tier_vpc.id
  cidr_block              = "10.0.2.0/24" # Rango de 256 IPs para AZ-B
  availability_zone       = data.aws_availability_zones.available.names[1] # Segunda AZ disponible
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-B"
  }
}

# 3.2. CAPA PRIVADA - APLICACIONES (EC2/ASG) - No accesible desde Internet.
resource "aws_subnet" "app_private_a" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "App-Private-A"
  }
}

resource "aws_subnet" "app_private_b" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "App-Private-B"
  }
}

# 3.3. CAPA PRIVADA - DATOS (RDS/Bases de Datos) - Máximo aislamiento.
resource "aws_subnet" "data_private_a" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "Data-Private-A"
  }
}

resource "aws_subnet" "data_private_b" {
  vpc_id            = aws_vpc.three_tier_vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "Data-Private-B"
  }
}

# 4. CONFIGURACIÓN DEL NAT GATEWAY (para tráfico de salida de la Capa Privada App)
# ---------------------------------------------------------------------------------
# Necesita una IP elástica (EIP) para ser accesible desde Internet (para el tráfico saliente).
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway: Colocado en la Subred Pública de la AZ-A (Solo necesitamos uno)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_a.id # Ubicación física en la Subred Pública de AZ-A
  tags = {
    Name = "main-nat-gw"
  }
}


# 5. TABLAS DE RUTAS Y ASOCIACIONES
# ==============================================================================

# 5.1. TABLA DE RUTAS PÚBLICA (Para las subredes de ALB y NAT Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.three_tier_vpc.id
  tags = {
    Name = "Public-RT"
  }
}

# RUTA PÚBLICA: Tráfico 0.0.0.0/0 (todo) va al IGW
resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id # El camino hacia Internet
}

# ASOCIACIÓN PÚBLICA: Vincula la tabla a ambas subredes públicas.
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# 5.2. TABLA DE RUTAS PRIVADA - APLICACIONES (Para EC2/ASG)
resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.three_tier_vpc.id
  tags = {
    Name = "App-Private-RT"
  }
}

# RUTA PRIVADA APP: Tráfico 0.0.0.0/0 (todo) va al NAT Gateway
resource "aws_route" "app_private_nat_route" {
  route_table_id         = aws_route_table.app_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id # Aquí está la clave: Tráfico saliente seguro
}

# ASOCIACIÓN PRIVADA APP: Vincula la tabla a ambas subredes de aplicación.
resource "aws_route_table_association" "app_private_a" {
  subnet_id      = aws_subnet.app_private_a.id
  route_table_id = aws_route_table.app_private.id
}

resource "aws_route_table_association" "app_private_b" {
  subnet_id      = aws_subnet.app_private_b.id
  route_table_id = aws_route_table.app_private.id
}

# 5.3. TABLA DE RUTAS PRIVADA - DATOS (Para RDS)
resource "aws_route_table" "data_private" {
  vpc_id = aws_vpc.three_tier_vpc.id
  tags = {
    Name = "Data-Private-RT"
  }
}

# IMPORTANTE: No se define ninguna ruta 0.0.0.0/0. 
# Esto garantiza que el tráfico de la base de datos no tenga salida a Internet.

# ASOCIACIÓN PRIVADA DATOS: Vincula la tabla a ambas subredes de datos.
resource "aws_route_table_association" "data_private_a" {
  subnet_id      = aws_subnet.data_private_a.id
  route_table_id = aws_route_table.data_private.id
}

resource "aws_route_table_association" "data_private_b" {
  subnet_id      = aws_subnet.data_private_b.id
  route_table_id = aws_route_table.data_private.id
}

# 6. GRUPOS DE SEGURIDAD (SECURITY GROUPS - SGs)
# ==============================================================================

# 6.1. SG para el ALB (Entrada web)
# Permite tráfico HTTP/HTTPS desde CUALQUIER LUGAR (Internet)
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.three_tier_vpc.id
  name   = "alb-sg"

  # INGRESO: Tráfico HTTP desde cualquier lugar
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Abierto a Internet
  }

  # INGRESO: Tráfico HTTPS desde cualquier lugar
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Abierto a Internet
  }

  # EGRESO: Permite todo el tráfico saliente por defecto (común para ALBs)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Cualquier protocolo
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB_SG"
  }
}

# 6.2. SG para las Instancias EC2/ASG (Capa de Aplicación)
# Solo permite tráfico desde el ALB y tráfico saliente al exterior (vía NAT)
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.three_tier_vpc.id
  name   = "app-sg"

  # INGRESO: SOLO permite el tráfico que viene del ALB
  ingress {
    from_port       = 8080 # Puerto de escucha de la aplicación (ejemplo)
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Referencia al SG del ALB
    description     = "Permitir trafico solo desde el ALB"
  }

  # EGRESO: Permite todo el tráfico saliente (incluyendo a RDS y a Internet vía NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "APP_SG"
  }
}

# 6.3. SG para RDS (Capa de Datos)
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

# 7. OUTPUTS (Salidas para referencia)
# ==============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.three_tier_vpc.id
}

output "public_subnet_ids" {
  description = "List of Public Subnet IDs"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "app_private_subnet_ids" {
  description = "List of App Private Subnet IDs"
  value       = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]
}

output "alb_security_group_id" {
  description = "The ID of the ALB Security Group"
  value       = aws_security_group.alb_sg.id
}

# 8. RECURSOS DE DATOS (AMAZON RDS)
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
  allocated_storage    = 20
  engine               = "postgres" # Ejemplo: Podría ser mysql, mariadb, etc.
  instance_class       = "db.t3.micro" # Tamaño pequeño para pruebas (Free Tier)
  username             = "appuser"
  password             = "PasswordSeguro123" # ¡USAR SECRETS MANAGER en producción!
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id] # El firewall de datos
  skip_final_snapshot  = true # Para que se destruya rápido al hacer 'terraform destroy'
}

# Modificar el Output para incluir el endpoint del RDS
output "rds_endpoint" {
  description = "El endpoint de la base de datos RDS para la conexión de la app"
  value       = aws_db_instance.app_db.address
}

# 9. BALANCEADOR DE CARGA (ALB)
# ==============================================================================

# Definición del ALB
resource "aws_lb" "application_lb" {
  name               = "mi-app-alb"
  internal           = false # Es público (accesible desde Internet)
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id] # Aplica el firewall de la web
  # El ALB se despliega en ambas subredes públicas para HA
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] 
  tags = {
    Name = "main-application-lb"
  }
}

# Target Group (TG): Grupo de destino al que el ALB enviará el tráfico (nuestro ASG)
resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 8080 # El puerto que usan las EC2 (debe coincidir con el SG)
  protocol = "HTTP"
  vpc_id   = aws_vpc.three_tier_vpc.id

  health_check {
    path = "/" # Ruta para verificar que la app esté viva
  }
}

# Listener del ALB: Escucha el tráfico entrante en el puerto 80 (HTTP)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Modificar el Output para incluir el DNS del ALB
output "alb_dns_name" {
  description = "El nombre DNS público del Application Load Balancer"
  value       = aws_lb.application_lb.dns_name
}

# 10. AUTO SCALING GROUP (EC2/ASG)
# ==============================================================================

# Configuración de Lanzamiento (Define cómo se construye cada instancia EC2)
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-lt-"
  image_id      = "ami-052064a798f08f0d3" # Amazon Linux 2023 (Ejemplo)
  instance_type = "t3.micro" # Free Tier
  key_name      = "KeyPair-Ec2lab" # Reemplazar con el nombre de tu clave SSH
  
  # Asigna el SG de la aplicación y permite que pueda acceder a RDS y salir via NAT
  vpc_security_group_ids = [aws_security_group.app_sg.id] 
  
  # user_data = filebase64("init-script.sh") # Se usaría un script de inicio real aquí
}

# Auto Scaling Group (ASG): Mantiene la aplicación viva y distribuye las instancias
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  health_check_type   = "ELB"
  
  vpc_zone_identifier = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]
  
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
  
  # Bloque de tags correcto para aws_autoscaling_group
  tag {
      key                 = "Name"
      value               = "app-server"
      propagate_at_launch = true
    }

  
  depends_on = [aws_db_instance.app_db] 
}