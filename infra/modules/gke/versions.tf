terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.0, < 8"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10, < 4"
    }
  }
}
