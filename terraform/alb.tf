# Application Load Balancer
resource "aws_lb" "main" {
  name               = "cloud-design-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Environment = "production"
    Project     = "cloud-design"
  }
}

# Target Group for API Gateway App (Port 3000)
resource "aws_lb_target_group" "api_gateway" {
  name        = "tg-api-gateway"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate awsvpc network mode

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ALB Listener on HTTP Port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}

# Output Load Balancer DNS Name
output "alb_dns_name" {
  description = "Public DNS name of the Load Balancer"
  value       = aws_lb.main.dns_name
}