output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}

output "argocd_server_service" {
  description = "ArgoCD server service name for port-forwarding"
  value       = "argocd-server"
}
