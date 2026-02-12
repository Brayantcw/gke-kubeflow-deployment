output "istio_namespace" {
  description = "Namespace where Istio is installed"
  value       = helm_release.istiod.namespace
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = helm_release.cert_manager.namespace
}

output "kubeflow_access_info" {
  description = "Instructions to access Kubeflow"
  value       = <<-EOT
    Access Kubeflow:
      kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
      Open http://localhost:8080
      Default credentials: user@example.com / 12341234
      IMPORTANT: Change the default password before any real use.
  EOT
}
