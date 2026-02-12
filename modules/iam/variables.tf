variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name, used as prefix for service accounts"
  type        = string
}

variable "create_kubeflow_sa" {
  description = "Whether to create the Kubeflow Pipelines service account with Workload Identity"
  type        = bool
  default     = false
}
