module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 43.0"

  project_id = var.project_id
  name       = var.cluster_name
  region     = var.region
  zones      = var.zones

  # Network
  network           = var.network_name
  subnetwork        = var.subnet_name
  ip_range_pods     = var.pods_range_name
  ip_range_services = var.services_range_name

  # Private cluster — nodes have no public IPs
  enable_private_nodes    = true
  enable_private_endpoint = false
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block

  # Authorized networks for API access
  master_authorized_networks = var.master_authorized_networks

  # Cluster config
  kubernetes_version         = var.kubernetes_version
  release_channel            = var.release_channel
  horizontal_pod_autoscaling = true
  http_load_balancing        = true
  deletion_protection        = false

  # Security
  enable_shielded_nodes = true

  # Workload Identity for secure pod-to-GCP-service auth
  identity_namespace = "${var.project_id}.svc.id.goog"

  # Logging and monitoring (free tier includes basic)
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Node pools
  remove_default_node_pool = true

  node_pools = [
    {
      name               = var.node_pool_name
      machine_type       = var.machine_type
      min_count          = var.min_node_count
      max_count          = var.max_node_count
      initial_node_count = var.initial_node_count
      disk_size_gb       = var.disk_size_gb
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      spot               = var.use_spot_instances
      service_account    = var.gke_service_account_email
    },
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]
  }

  node_pools_labels = {
    all = var.labels
  }

  node_pools_tags = {
    all = var.node_tags
  }
}
