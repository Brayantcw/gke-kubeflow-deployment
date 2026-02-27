variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.8.8"
}

variable "argocd_namespace" {
  description = "Namespace for ArgoCD installation"
  type        = string
  default     = "argocd"
}

variable "gitops_repo_url" {
  description = "Git repository URL that ArgoCD will watch for gitops/ manifests"
  type        = string
}

variable "gitops_revision" {
  description = "Git branch or tag ArgoCD will track"
  type        = string
  default     = "main"
}

variable "gitops_path" {
  description = "Path within the repo to the ArgoCD app-of-apps definition"
  type        = string
  default     = "gitops/argocd"
}
