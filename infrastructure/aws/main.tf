terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = "pgagi-devops", Environment = var.environment, ManagedBy = "terraform" }
  }
}

module "networking" {
  source      = "./modules/networking"
  environment = var.environment
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr
}

module "security" {
  source      = "./modules/security"
  environment = var.environment
  vpc_id      = module.networking.vpc_id
}

module "compute" {
  source             = "./modules/compute"
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  frontend_sg_id     = module.security.frontend_sg_id
  backend_sg_id      = module.security.backend_sg_id
  alb_sg_id          = module.security.alb_sg_id
  frontend_image     = var.frontend_image
  backend_image      = var.backend_image
  frontend_cpu       = var.frontend_cpu
  frontend_memory    = var.frontend_memory
  backend_cpu        = var.backend_cpu
  backend_memory     = var.backend_memory
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  execution_role_arn = module.security.ecs_execution_role_arn
  task_role_arn      = module.security.ecs_task_role_arn
}
