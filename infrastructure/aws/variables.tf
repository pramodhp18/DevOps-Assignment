variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type = string
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "frontend_image" {
  type = string
}
variable "backend_image" {
  type = string
}
variable "frontend_cpu" {
  type    = number
  default = 256
}
variable "frontend_memory" {
  type    = number
  default = 512
}
variable "backend_cpu" {
  type    = number
  default = 256
}
variable "backend_memory" {
  type    = number
  default = 512
}
variable "min_capacity" {
  type    = number
  default = 1
}
variable "max_capacity" {
  type    = number
  default = 2
}
