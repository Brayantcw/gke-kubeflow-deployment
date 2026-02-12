# GKE Kubeflow Deployment

Modular Terraform project for deploying Kubeflow on a private GKE cluster in Google Cloud.

## Module Structure

```
├── modules/
│   ├── network/     VPC, subnets (pod/service secondary ranges), Cloud NAT, firewall
│   ├── gke/         Private GKE cluster with autoscaling node pools
│   ├── iam/         Dedicated node SA, Kubeflow Pipelines SA, Workload Identity
│   └── kubeflow/    Istio + cert-manager (Helm), Kubeflow components (kustomize)
├── environments/
│   └── dev/         Dev environment composing all modules
└── .github/
    └── workflows/   CI/CD: plan/apply + destroy
```

## Supported Versions

| Component | Version | Source |
|---|---|---|
| Terraform | >= 1.3 | — |
| Google Provider | ~> 7.0 | `hashicorp/google` |
| GKE Module | ~> 43.0 | `terraform-google-modules/kubernetes-engine` |
| Network Module | ~> 15.0 | `terraform-google-modules/network` |
| Kubeflow | v1.11 | `kubeflow/manifests` (kustomize) |
| Istio | 1.24.3 | Helm chart |
| cert-manager | v1.17.2 | Helm chart |
| Kustomization Provider | ~> 0.9 | `kbst/kustomization` |

## Kubeflow Components

Each component can be independently enabled or disabled via `terraform.tfvars`:

| Component | Variable | Default | Description |
|---|---|---|---|
| Pipelines | `enable_pipelines` | `true` | ML workflow orchestration |
| Notebooks | `enable_notebooks` | `true` | Jupyter notebook server |
| Katib | `enable_katib` | `true` | Hyperparameter tuning / AutoML |
| Training Operator | `enable_training_operator` | `true` | Distributed training (PyTorch, TF) |
| Tensorboard | `enable_tensorboard` | `true` | Training visualization |
| Volumes Web App | `enable_volumes_web_app` | `true` | PVC management UI |
| KServe | `enable_kserve` | `false` | Model serving |
| Knative Eventing | `enable_knative_eventing` | `false` | Event-driven workflows |
| Spark Operator | `enable_spark_operator` | `false` | Apache Spark on K8s |
| User Namespace | `enable_user_namespace` | `true` | Default user profile |

Set `install_kubeflow = false` to deploy only the GKE infrastructure without Kubeflow.

## Security

- **Private cluster** — nodes have no public IPs, outbound traffic via Cloud NAT
- **Workload Identity** — pods authenticate to GCP services without exported keys
- **Least-privilege SA** — dedicated node service account with only logging, monitoring, and artifact registry roles
- **Shielded nodes** — secure boot and integrity monitoring
- **Master authorized networks** — configurable API server access restriction
- **CI/CD auth** — Workload Identity Federation for GitHub Actions (no SA key secrets)

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- Terraform >= 1.3

## Usage

### Local Deployment

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# Set your project_id and adjust component toggles
```

```bash
terraform init
terraform plan
terraform apply
```

### Connect to the Cluster

```bash
$(terraform output -raw kubeconfig_command)
kubectl get nodes
```

### Access Kubeflow

After apply completes, pods take 5-10 minutes to become ready.

```bash
kubectl get pods -n kubeflow
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
# Open http://localhost:8080
# Default credentials: user@example.com / 12341234
```

## CI/CD

Two GitHub Actions workflows:

| Workflow | Trigger | Pipeline |
|---|---|---|
| `terraform.yml` | Push to `main`, PRs, manual | fmt → validate → plan → apply |
| `terraform-destroy.yml` | Manual only | confirm → plan destroy → destroy |

- **Apply** requires `production` environment approval
- **Destroy** requires typing `"destroy"` + `destroy` environment approval

### GCP Authentication (Workload Identity Federation)

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="YOUR_PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create OIDC Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="YOUR_PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create Terraform Service Account
gcloud iam service-accounts create "terraform-github" \
  --project="YOUR_PROJECT_ID" \
  --display-name="Terraform GitHub Actions"

# Grant roles
for role in roles/editor roles/iam.securityAdmin roles/container.admin; do
  gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:terraform-github@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role"
done

# Allow GitHub to impersonate the SA
gcloud iam service-accounts add-iam-policy-binding \
  "terraform-github@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --project="YOUR_PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/Brayantcw/gke-kubeflow-deployment"
```

### GitHub Configuration

**Secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | `terraform-github@YOUR_PROJECT_ID.iam.gserviceaccount.com` |

**Environments** (Settings → Environments):

- `production` — required reviewers for apply
- `destroy` — required reviewers for destroy

## Teardown

Via GitHub Actions:
1. **Actions → Terraform Destroy → Run workflow**
2. Type `destroy` to confirm

Locally:
```bash
cd environments/dev
terraform destroy
```
