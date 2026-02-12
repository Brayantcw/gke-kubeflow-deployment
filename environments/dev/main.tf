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

# --- Kubeflow ---
module "kubeflow" {
  source = "../../modules/kubeflow"

  cluster_endpoint       = module.gke.cluster_endpoint
  cluster_ca_certificate = module.gke.cluster_ca_certificate

  # Versions
  install_kubeflow     = var.install_kubeflow
  kubeflow_version     = var.kubeflow_version
  istio_version        = var.istio_version
  cert_manager_version = var.cert_manager_version

  # Component toggles
  enable_pipelines         = var.enable_pipelines
  enable_notebooks         = var.enable_notebooks
  enable_katib             = var.enable_katib
  enable_kserve            = var.enable_kserve
  enable_training_operator = var.enable_training_operator
  enable_tensorboard       = var.enable_tensorboard
  enable_volumes_web_app   = var.enable_volumes_web_app
  enable_knative_eventing  = var.enable_knative_eventing
  enable_spark_operator    = var.enable_spark_operator
  enable_user_namespace    = var.enable_user_namespace

  depends_on = [module.gke]
}
