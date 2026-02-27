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

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = module.argocd_bootstrap.argocd_namespace
}

output "argocd_access_info" {
  description = "How to access ArgoCD and Kubeflow dashboards"
  value       = <<-EOT
    ArgoCD UI:
      kubectl port-forward svc/argocd-server -n argocd 8443:443
      Open https://localhost:8443
      Username: admin
      Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

    Kubeflow UI (after ArgoCD syncs all apps):
      kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
      Open http://localhost:8080
      Default credentials: user@example.com / 12341234
  EOT
}
