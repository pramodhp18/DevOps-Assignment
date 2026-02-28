output "frontend_url"       { value = "http://${module.compute.alb_dns_name}" }
output "backend_health_url" { value = "http://${module.compute.alb_dns_name}/api/health" }
output "alb_dns_name"       { value = module.compute.alb_dns_name }
output "ecs_cluster_name"   { value = module.compute.ecs_cluster_name }
