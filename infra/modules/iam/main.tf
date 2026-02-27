# Dedicated service account for GKE nodes (least-privilege, replaces default compute SA)
resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Nodes SA for ${var.cluster_name}"
}

# Minimum roles for GKE nodes to function
resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Workload Identity binding for Kubeflow pipelines (example)
resource "google_service_account" "kubeflow_pipelines" {
  count        = var.create_kubeflow_sa ? 1 : 0
  project      = var.project_id
  account_id   = "${var.cluster_name}-kf-pipelines"
  display_name = "Kubeflow Pipelines SA for ${var.cluster_name}"
}

resource "google_project_iam_member" "kubeflow_pipelines_storage" {
  count   = var.create_kubeflow_sa ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.kubeflow_pipelines[0].email}"
}

# Workload Identity binding: allows K8s SA to impersonate GCP SA
resource "google_service_account_iam_member" "kubeflow_pipelines_wi" {
  count              = var.create_kubeflow_sa ? 1 : 0
  service_account_id = google_service_account.kubeflow_pipelines[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kubeflow/ml-pipeline]"
}
