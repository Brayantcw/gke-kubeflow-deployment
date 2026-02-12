terraform {
  required_version = ">= 1.3"

  # Uncomment and configure for remote state:
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "dev/kubeflow"
  # }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "~> 0.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Authenticate Helm and Kubernetes providers via GKE cluster
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}

provider "kustomization" {
  kubeconfig_raw = <<-KUBECONFIG
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        server: https://${module.gke.cluster_endpoint}
        certificate-authority-data: ${module.gke.cluster_ca_certificate}
      name: gke
    contexts:
    - context:
        cluster: gke
        user: gke
      name: gke
    current-context: gke
    users:
    - name: gke
      user:
        token: ${data.google_client_config.default.access_token}
  KUBECONFIG
}
