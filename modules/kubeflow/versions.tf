terraform {
  required_version = ">= 1.3"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10, < 3"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = ">= 0.9, < 1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
