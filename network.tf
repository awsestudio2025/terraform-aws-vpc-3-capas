#   TF con Despliegue de:
#       -VPC (virtual private cloud)
#       -IGW (Internet Gateway)
#       -2 Subredes Publicas 
#       -2 Subredes Privadas APP (EC2/ASG)
#       -2 Subredes Privadas DATA (RDS postgres)
#       -NAT Gateway
#       -Route table trafico 

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

# 3.1. CAPA PÚBLICA (Web/ALB) - Necesita ser accesible desde Internet
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.three_tier_vpc.id # Asocia esta subred a la VPC que acabamos de crear.
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

# ==============================================================================

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

# ==============================================================================

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