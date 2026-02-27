variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "zones" {
  description = "Zones for the cluster nodes"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Use 'latest' for the latest available."
  type        = string
  default     = "latest"
}

variable "release_channel" {
  description = "Release channel for GKE. One of: UNSPECIFIED, RAPID, REGULAR, STABLE."
  type        = string
  default     = "REGULAR"
}

# Network references
variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range for services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks authorized to access the GKE master"
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

# Node pool config
variable "node_pool_name" {
  description = "Name of the default node pool"
  type        = string
  default     = "default-pool"
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "min_node_count" {
  description = "Minimum number of nodes per zone"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes per zone"
  type        = number
  default     = 3
}

variable "initial_node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 1
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node"
  type        = number
  default     = 50
}

variable "use_spot_instances" {
  description = "Use Spot VMs for cost savings (can be preempted)"
  type        = bool
  default     = true
}

variable "gke_service_account_email" {
  description = "Service account email for GKE nodes"
  type        = string
}

variable "labels" {
  description = "Labels to apply to node pools"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "Network tags for node pool instances"
  type        = list(string)
  default     = ["gke-node"]
}
