variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
  default     = "gke-pods"
}

variable "pods_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_range_name" {
  description = "Name of the secondary range for services"
  type        = string
  default     = "gke-services"
}

variable "services_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.20.0.0/20"
}
