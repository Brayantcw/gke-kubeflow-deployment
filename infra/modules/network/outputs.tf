output "network_id" {
  description = "VPC network ID"
  value       = module.vpc.network_id
}

output "network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = module.vpc.network_self_link
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.vpc.subnets["${var.region}/${var.subnet_name}"].name
}

output "subnet_self_link" {
  description = "Subnet self link"
  value       = module.vpc.subnets["${var.region}/${var.subnet_name}"].self_link
}

output "pods_range_name" {
  description = "Name of the pods secondary range"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Name of the services secondary range"
  value       = var.services_range_name
}
