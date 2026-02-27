locals {
  project_id   = var.project_id
  region       = var.region
  cluster_name = "${var.environment}-${var.service_name}"
  network_name = "${var.environment}-vpc"
  subnet_name  = "${var.environment}-subnet"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    service     = var.service_name
  }
}

# --- Required GCP APIs ---
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  project            = local.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- IAM ---
module "iam" {
  source = "../../modules/iam"

  project_id         = local.project_id
  cluster_name       = local.cluster_name
  create_kubeflow_sa = var.create_kubeflow_sa

  depends_on = [google_project_service.required_apis]
}

# --- Network ---
module "network" {
  source = "../../modules/network"

  project_id    = local.project_id
  region        = local.region
  network_name  = local.network_name
  subnet_name   = local.subnet_name
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr

  depends_on = [google_project_service.required_apis]
}

# --- GKE ---
module "gke" {
  source = "../../modules/gke"

  project_id   = local.project_id
  region       = local.region
  zones        = var.zones
  cluster_name = local.cluster_name

  # Network
  network_name        = module.network.network_name
  subnet_name         = module.network.subnet_name
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  # Cluster
  kubernetes_version = var.kubernetes_version
  release_channel    = "REGULAR"

  # Node pool — cost-optimized for free tier
  machine_type       = var.machine_type
  min_node_count     = var.min_node_count
  max_node_count     = var.max_node_count
  initial_node_count = var.initial_node_count
  disk_size_gb       = var.disk_size_gb
  use_spot_instances = var.use_spot_instances

  # Security
  gke_service_account_email  = module.iam.gke_nodes_service_account_email
  master_authorized_networks = var.master_authorized_networks

  labels    = local.labels
  node_tags = ["${local.cluster_name}-node"]

  depends_on = [module.network, module.iam]
}

# --- ArgoCD Bootstrap ---
# Installs ArgoCD and creates a root Application that points to gitops/.
# ArgoCD then takes over deploying Istio, cert-manager, and Kubeflow.
module "argocd_bootstrap" {
  source = "../../modules/argocd-bootstrap"

  argocd_version = var.argocd_version
  gitops_repo_url = var.gitops_repo_url
  gitops_revision = var.gitops_revision
  gitops_path     = var.gitops_path

  depends_on = [module.gke]
}
