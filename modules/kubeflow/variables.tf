variable "cluster_endpoint" {
  description = "GKE cluster endpoint (used as trigger for re-provisioning)"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  type        = string
  sensitive   = true
}

# --- Version pins ---

variable "kubeflow_version" {
  description = "Kubeflow manifests git branch/tag. All component versions are coordinated within a branch."
  type        = string
  default     = "v1.11-branch"
}

variable "istio_version" {
  description = "Istio Helm chart version"
  type        = string
  default     = "1.24.3"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.17.2"
}

variable "manifests_path" {
  description = "Local path where Kubeflow manifests will be cloned"
  type        = string
  default     = "/tmp/kubeflow-manifests"
}

# --- Master toggle ---

variable "install_kubeflow" {
  description = "Install Kubeflow platform. Set false to only deploy Istio + cert-manager."
  type        = bool
  default     = true
}

# --- Per-component toggles ---
# Each maps to a kustomize overlay in the Kubeflow manifests repo.
# Disabling a component skips its kustomization_build + kustomization_resource entirely.

variable "enable_pipelines" {
  description = "Install Kubeflow Pipelines (ML workflow orchestration)"
  type        = bool
  default     = true
}

variable "enable_notebooks" {
  description = "Install Jupyter Notebook controller and web app"
  type        = bool
  default     = true
}

variable "enable_katib" {
  description = "Install Katib (hyperparameter tuning and AutoML)"
  type        = bool
  default     = true
}

variable "enable_kserve" {
  description = "Install KServe (model serving). Requires Knative Serving."
  type        = bool
  default     = false
}

variable "enable_training_operator" {
  description = "Install Training Operator v2 (distributed training: PyTorch, TensorFlow, etc.)"
  type        = bool
  default     = true
}

variable "enable_tensorboard" {
  description = "Install Tensorboard controller and web app"
  type        = bool
  default     = true
}

variable "enable_volumes_web_app" {
  description = "Install Volumes Web App (PVC management UI)"
  type        = bool
  default     = true
}

variable "enable_knative_eventing" {
  description = "Install Knative Eventing (event-driven workflows). Not required for most setups."
  type        = bool
  default     = false
}

variable "enable_spark_operator" {
  description = "Install Spark Operator (Apache Spark on Kubernetes)"
  type        = bool
  default     = false
}

variable "enable_user_namespace" {
  description = "Create the default user namespace (user@example.com profile)"
  type        = bool
  default     = true
}
