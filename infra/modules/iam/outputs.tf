output "gke_nodes_service_account_email" {
  description = "Email of the GKE nodes service account"
  value       = google_service_account.gke_nodes.email
}

output "gke_nodes_service_account_id" {
  description = "ID of the GKE nodes service account"
  value       = google_service_account.gke_nodes.id
}

output "kubeflow_pipelines_service_account_email" {
  description = "Email of the Kubeflow Pipelines service account"
  value       = var.create_kubeflow_sa ? google_service_account.kubeflow_pipelines[0].email : ""
}
