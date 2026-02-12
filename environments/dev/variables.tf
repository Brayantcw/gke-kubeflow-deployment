variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region. us-central1 has good free-tier coverage."
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "Zones for GKE nodes. Single zone reduces cost."
  type        = list(string)
  default     = ["us-central1-a"]
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "service_name" {
  description = "Service name suffix"
  type        = string
  default     = "kubeflow"
}

# Network
variable "subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range CIDR for pods"
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range CIDR for services"
  type        = string
  default     = "10.20.0.0/20"
}

# GKE
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "latest"
}

variable "machine_type" {
  description = "Machine type for nodes. e2-standard-4 balances cost and Kubeflow requirements."
  type        = string
  default     = "e2-standard-4"
}

variable "min_node_count" {
  description = "Minimum nodes per zone"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum nodes per zone"
  type        = number
  default     = 3
}

variable "initial_node_count" {
  description = "Initial nodes per zone"
  type        = number
  default     = 1
}

variable "disk_size_gb" {
  description = "Disk size per node in GB"
  type        = number
  default     = 50
}

variable "use_spot_instances" {
  description = "Use Spot VMs to reduce cost (up to 60-91% cheaper, but can be preempted)"
  type        = bool
  default     = true
}

variable "master_authorized_networks" {
  description = "CIDR blocks authorized to access the GKE API server"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all-access"
    }
  ]
}

# Kubeflow
variable "create_kubeflow_sa" {
  description = "Create Kubeflow Pipelines service account with Workload Identity"
  type        = bool
  default     = false
}

variable "install_kubeflow" {
  description = "Install Kubeflow platform (Istio, cert-manager, and Kubeflow manifests)"
  type        = bool
  default     = true
}

variable "kubeflow_version" {
  description = "Kubeflow manifests git branch/tag. Component versions are coordinated within a branch."
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

# --- Kubeflow component toggles ---

variable "enable_pipelines" {
  description = "Install Kubeflow Pipelines"
  type        = bool
  default     = true
}

variable "enable_notebooks" {
  description = "Install Jupyter Notebooks"
  type        = bool
  default     = true
}

variable "enable_katib" {
  description = "Install Katib (hyperparameter tuning)"
  type        = bool
  default     = true
}

variable "enable_kserve" {
  description = "Install KServe (model serving)"
  type        = bool
  default     = false
}

variable "enable_training_operator" {
  description = "Install Trainer v2 (distributed training)"
  type        = bool
  default     = true
}

variable "enable_tensorboard" {
  description = "Install Tensorboard"
  type        = bool
  default     = true
}

variable "enable_volumes_web_app" {
  description = "Install Volumes Web App"
  type        = bool
  default     = true
}

variable "enable_knative_eventing" {
  description = "Install Knative Eventing"
  type        = bool
  default     = false
}

variable "enable_spark_operator" {
  description = "Install Spark Operator"
  type        = bool
  default     = false
}

variable "enable_user_namespace" {
  description = "Create default user namespace"
  type        = bool
  default     = true
}
