output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = module.gke.location
}

output "network_name" {
  description = "VPC network name"
  value       = module.network.network_name
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.network.subnet_name
}

output "gke_nodes_sa_email" {
  description = "GKE nodes service account email"
  value       = module.iam.gke_nodes_service_account_email
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "kubeflow_access_info" {
  description = "How to access Kubeflow dashboard"
  value       = module.kubeflow.kubeflow_access_info
}
