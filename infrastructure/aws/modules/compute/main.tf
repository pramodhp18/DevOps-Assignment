variable "environment"        {}
variable "aws_region"         {}
variable "vpc_id"             {}
variable "public_subnet_ids"  {}
variable "private_subnet_ids" {}
variable "frontend_sg_id"     {}
variable "backend_sg_id"      {}
variable "alb_sg_id"          {}
variable "frontend_image"     {}
variable "backend_image"      {}
variable "frontend_cpu"       {}
variable "frontend_memory"    {}
variable "backend_cpu"        {}
variable "backend_memory"     {}
variable "min_capacity"       {}
variable "max_capacity"       {}
variable "execution_role_arn" {}
variable "task_role_arn"      {}

locals {
  task_subnet_ids = var.environment == "dev" ? var.public_subnet_ids : var.private_subnet_ids
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/pgagi-${var.environment}/frontend"
  retention_in_days = var.environment == "prod" ? 30 : 7
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/pgagi-${var.environment}/backend"
  retention_in_days = var.environment == "prod" ? 30 : 7
}

resource "aws_ecs_cluster" "main" {
  name = "pgagi-${var.environment}"
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "pgagi-${var.environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image
    essential = true
    portMappings = [{ containerPort = 8000, protocol = "tcp" }]
    environment  = [{ name = "ENV", value = var.environment }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/api/health || exit 1"]
      interval    = 30
      timeout = 5
      retries = 3
      startPeriod = 30
    }
  }])
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "pgagi-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.frontend_cpu
  memory                   = var.frontend_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name      = "frontend"
    image     = var.frontend_image
    essential = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment  = [
      { name = "NODE_ENV", value = "production" },
      { name = "NEXT_PUBLIC_API_URL", value = "http://${aws_lb.main.dns_name}" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:3000 || exit 1"]
      interval    = 30
      timeout = 5
      retries = 3
      startPeriod = 60
    }
  }])
}

resource "aws_lb" "main" {
  name               = "pgagi-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = var.environment == "prod"
}

resource "aws_lb_target_group" "frontend" {
  name        = "pgagi-${var.environment}-fe"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/"
    interval = 30
    healthy_threshold = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "pgagi-${var.environment}-be"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/api/health"
    interval = 30
    healthy_threshold = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.min_capacity
  launch_type     = "FARGATE"
  deployment_minimum_healthy_percent = var.environment == "dev" ? 0 : 50
  deployment_maximum_percent         = 200
  network_configuration {
    subnets          = local.task_subnet_ids
    security_groups  = [var.backend_sg_id]
    assign_public_ip = var.environment == "dev"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }
  lifecycle { ignore_changes = [desired_count] }
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.min_capacity
  launch_type     = "FARGATE"
  deployment_minimum_healthy_percent = var.environment == "dev" ? 0 : 50
  deployment_maximum_percent         = 200
  network_configuration {
    subnets          = local.task_subnet_ids
    security_groups  = [var.frontend_sg_id]
    assign_public_ip = var.environment == "dev"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }
  lifecycle { ignore_changes = [desired_count] }
}

output "alb_dns_name"     { value = aws_lb.main.dns_name }
output "ecs_cluster_name" { value = aws_ecs_cluster.main.name }
