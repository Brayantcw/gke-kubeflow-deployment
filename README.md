# GKE Kubeflow Deployment

Terraform modules for deploying a GKE cluster on GCP, designed for Kubeflow workloads. Optimized for the GCP free tier + $300 trial credits.

## Architecture

```
gke-kubeflow-deployment/
├── modules/
│   ├── network/    # VPC, subnets, Cloud NAT, firewall
│   ├── gke/        # Private GKE cluster with autoscaling
│   ├── iam/        # Least-privilege service accounts, Workload Identity
│   └── kubeflow/   # Istio (Helm), cert-manager (Helm), Kubeflow (kustomize)
└── environments/
    └── dev/        # Dev environment wiring all modules
```

### Cost Optimization Decisions

| Decision | Rationale |
|---|---|
| Single zone (`us-central1-a`) | Avoids multi-zone node replication costs |
| Spot VMs (`e2-standard-4`) | 60-91% cheaper than on-demand |
| 50GB `pd-standard` disks | Cheaper than SSD, sufficient for dev |
| Single NAT gateway | Reduces NAT hourly costs |
| Autoscaling 1-3 nodes | Scales down when idle |

### Security

- **Private cluster**: Nodes have no public IPs; outbound via Cloud NAT
- **Workload Identity**: Pods authenticate to GCP services without key files
- **Least-privilege SA**: Dedicated node SA with only logging/monitoring/artifact roles
- **Shielded nodes**: Secure boot and integrity monitoring enabled
- **Master authorized networks**: Configurable API server access restriction

## Prerequisites

1. A GCP project with billing enabled (free tier + $300 credits)
2. `gcloud` CLI authenticated: `gcloud auth application-default login`
3. Terraform >= 1.3

## Deployment

### Step 1: Configure

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project ID
```

### Step 2: Deploy

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Connect to the cluster

```bash
# The command is printed as a Terraform output
$(terraform output -raw kubeconfig_command)

# Verify
kubectl get nodes
```

### Step 4: Access Kubeflow

Kubeflow is installed automatically (Istio + cert-manager via Helm, Kubeflow v1.11 via kustomize manifests). After `terraform apply` completes, pods take 5-10 minutes to become ready.

```bash
# Check pod status
kubectl get pods -n kubeflow

# Port-forward to access the dashboard
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80

# Open http://localhost:8080
# Default credentials: user@example.com / 12341234
```

To skip Kubeflow installation (infra only), set `install_kubeflow = false` in `terraform.tfvars`.

## Teardown

```bash
cd environments/dev
terraform destroy
```

## Estimated Monthly Cost (Dev)

With Spot VMs and single-zone, expect ~$30-60/month for a 1-node cluster. Scale to 0 by destroying when not in use to stay within the $300 credit budget.
