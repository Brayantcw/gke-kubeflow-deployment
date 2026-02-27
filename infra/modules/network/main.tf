module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 15.0"

  project_id   = var.project_id
  network_name = var.network_name

  subnets = [
    {
      subnet_name           = var.subnet_name
      subnet_ip             = var.subnet_cidr
      subnet_region         = var.region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    (var.subnet_name) = [
      {
        range_name    = var.pods_range_name
        ip_cidr_range = var.pods_cidr
      },
      {
        range_name    = var.services_range_name
        ip_cidr_range = var.services_cidr
      },
    ]
  }
}

# Cloud Router for NAT (private nodes need outbound internet)
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = module.vpc.network_id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall: allow internal communication within the VPC
resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "${var.network_name}-allow-internal"
  network = module.vpc.network_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]
}
