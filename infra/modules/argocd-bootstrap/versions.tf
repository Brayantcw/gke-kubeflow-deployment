terraform {
  required_version = ">= 1.5"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10, < 3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10, < 4"
    }
  }
}
