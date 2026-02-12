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

## CI/CD (GitHub Actions)

Two workflows are provided:

| Workflow | Trigger | Purpose |
|---|---|---|
| `terraform.yml` | Push to `main`, PRs, manual | Format, validate, plan, apply |
| `terraform-destroy.yml` | Manual only | Destroy all infrastructure |

### How it works

- **PR opened** → runs fmt, validate, plan. Posts plan output as PR comment.
- **Merge to main** → runs plan + apply. Apply requires `production` environment approval.
- **Manual dispatch** → same as push to main, with environment selector.
- **Destroy** → manual only, requires typing "destroy" to confirm + `destroy` environment approval.

### GCP Authentication Setup

The workflows use **Workload Identity Federation** (no service account keys). One-time setup:

```bash
# 1. Create a Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="YOUR_PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# 2. Create a Provider for GitHub
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="YOUR_PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 3. Create a Service Account for Terraform
gcloud iam service-accounts create "terraform-github" \
  --project="YOUR_PROJECT_ID" \
  --display-name="Terraform GitHub Actions"

# 4. Grant required roles
for role in roles/editor roles/iam.securityAdmin roles/container.admin; do
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-github@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role"
done

# 5. Allow GitHub Actions to impersonate the SA
gcloud iam service-accounts add-iam-policy-binding \
  "terraform-github@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --project="YOUR_PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/Brayantcw/gke-kubeflow-deployment"
```

### GitHub Secrets

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | `terraform-github@YOUR_PROJECT_ID.iam.gserviceaccount.com` |

### GitHub Environments

Create two environments in **Settings → Environments**:

- **`production`** — add required reviewers for apply approval
- **`destroy`** — add required reviewers for destroy approval

## Teardown

Via GitHub Actions (recommended):
1. Go to **Actions → Terraform Destroy → Run workflow**
2. Type `destroy` to confirm

Or locally:
```bash
cd environments/dev
terraform destroy
```

## Estimated Monthly Cost (Dev)

With Spot VMs and single-zone, expect ~$30-60/month for a 1-node cluster. Scale to 0 by destroying when not in use to stay within the $300 credit budget.
