#   TF con IaC para el despliegue de:
#        -Security Groups para EC2/ASG
#        -Security Groups ALB
#        -ALB (Aplication Load Balancing)
#        -EC2 con ASG (EC2 con Auto scaling Groups)

#1. GRUPOS DE SEGURIDAD (SECURITY GROUPS - SGs)
# ==============================================================================

# 1.1. SG para el ALB (Entrada web)
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

# 1.2. SG para las Instancias EC2/ASG (Capa de Aplicación)
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

# 2. BALANCEADOR DE CARGA (ALB)
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

# 3. AUTO SCALING GROUP (EC2/ASG)
# ==============================================================================

# Configuración de Lanzamiento (Define cómo se construye cada instancia EC2)
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-lt-"
  image_id      = var.instance_ami_id_app
  instance_type = var.instance_type_app
  key_name      = var.ssh_key_name
  
  # Asigna el SG de la aplicación y permite que pueda acceder a RDS y salir via NAT
  vpc_security_group_ids = [aws_security_group.app_sg.id] 
  
  # user_data = filebase64("init-script.sh") # Se usaría un script de inicio real aquí
}

# Auto Scaling Group (ASG): Mantiene la aplicación viva y distribuye las instancias
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
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