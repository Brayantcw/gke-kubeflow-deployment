output "cluster_id" {
  description = "GKE cluster ID"
  value       = module.gke.cluster_id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "location" {
  description = "GKE cluster location"
  value       = module.gke.location
}

output "master_version" {
  description = "Current master Kubernetes version"
  value       = module.gke.master_version
}

output "identity_namespace" {
  description = "Workload Identity namespace"
  value       = module.gke.identity_namespace
}

output "node_pools_names" {
  description = "List of node pool names"
  value       = module.gke.node_pools_names
}
