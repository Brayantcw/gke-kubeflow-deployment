# GKE Kubeflow Deployment

Deploys Kubeflow on a private GKE cluster using a two-layer architecture:
- **Terraform** provisions cloud infrastructure (VPC, GKE, IAM) and bootstraps ArgoCD
- **ArgoCD** manages all in-cluster workloads (Istio, cert-manager, Kubeflow) with continuous reconciliation

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Terraform (infra/)                          │
│                                                                 │
│  VPC + Subnets + NAT ──► GKE Cluster ──► IAM ──► ArgoCD        │
│                                                                 │
│  Terraform creates the cluster and installs ArgoCD.             │
│  ArgoCD is seeded with a root Application pointing to gitops/.  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ ArgoCD watches gitops/ and syncs
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ArgoCD (gitops/)                             │
│                                                                 │
│  Istio (Helm) ──► cert-manager (Helm) ──► Kubeflow (Kustomize) │
│                                                                 │
│  Continuous reconciliation: drift detection + self-healing.     │
│  Upgrades = change a version in git, merge, ArgoCD syncs.       │
└─────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
├── infra/                              Terraform — cloud infrastructure
│   ├── modules/
│   │   ├── network/                    VPC, subnets, Cloud NAT, firewall
│   │   ├── gke/                        Private GKE cluster with autoscaling
│   │   ├── iam/                        Node SA, Kubeflow Pipelines SA, Workload Identity
│   │   └── argocd-bootstrap/           Installs ArgoCD + seeds root Application
│   └── environments/
│       └── dev/                        Dev environment composing all modules
│
├── gitops/                             ArgoCD — in-cluster workloads
│   ├── argocd/                         App-of-apps: defines all ArgoCD Applications
│   └── apps/
│       ├── istio/                      Istio base, istiod, ingress gateway (Helm)
│       ├── cert-manager/               cert-manager (Helm)
│       └── kubeflow/                   Kubeflow components (upstream kustomize)
│           ├── base/                   Core: namespace, roles, Dex, oauth2-proxy, etc.
│           └── components/             Optional: Pipelines, Notebooks, Katib, etc.
│
├── .github/workflows/
│   ├── terraform.yml                   Pipeline 1: infra changes (plan → apply)
│   ├── terraform-destroy.yml           Manual destroy with confirmation
│   └── gitops-lint.yml                 Pipeline 2: validate kustomize builds
└── README.md
```

## Dependency Flow

```
1. terraform apply
   └── Creates: VPC → GKE → IAM → ArgoCD (Helm)
       └── Seeds: root ArgoCD Application → watches gitops/argocd/

2. ArgoCD syncs automatically (no manual step)
   └── Sync wave 1: Istio base CRDs
   └── Sync wave 2: istiod, cert-manager, Knative, Kubeflow namespace/roles
   └── Sync wave 3: Istio gateway, Dex, oauth2-proxy
   └── Sync wave 4: Central Dashboard, Admission Webhook, Profiles
   └── Sync wave 5: Pipelines, Notebooks, Katib, Training Operator, etc.
```

After `terraform apply` completes, ArgoCD starts syncing immediately. Kubeflow components take 10-15 minutes to fully deploy.

## Versions

| Component | Version | Source |
|---|---|---|
| Terraform | >= 1.5 | — |
| Google Provider | ~> 7.0 | `hashicorp/google` |
| GKE Module | ~> 43.0 | `terraform-google-modules/kubernetes-engine` |
| Network Module | ~> 15.0 | `terraform-google-modules/network` |
| ArgoCD | 7.8.8 | Helm chart (`argoproj/argo-helm`) |
| Kubeflow | v1.11.0 | `kubeflow/manifests` (kustomize, pinned tag) |
| Istio | 1.24.3 | Helm chart |
| cert-manager | v1.17.2 | Helm chart |

## Kubeflow Components

Enable/disable by commenting lines in `gitops/apps/kubeflow/kustomization.yaml`:

| Component | File | Default |
|---|---|---|
| Pipelines | `components/pipelines.yaml` | Enabled |
| Notebooks | `components/notebooks.yaml` | Enabled |
| Katib | `components/katib.yaml` | Enabled |
| Training Operator | `components/training-operator.yaml` | Enabled |
| Tensorboard | `components/tensorboard.yaml` | Enabled |
| Volumes Web App | `components/volumes-web-app.yaml` | Enabled |
| KServe | `components/kserve.yaml` | Disabled |
| Knative Eventing | `components/knative-eventing.yaml` | Disabled |
| Spark Operator | `components/spark-operator.yaml` | Disabled |

## Security

- **Private cluster** — nodes have no public IPs, outbound via Cloud NAT
- **Workload Identity** — pods authenticate to GCP without exported keys
- **Least-privilege SA** — dedicated node SA with logging, monitoring, artifact registry roles
- **Shielded nodes** — secure boot and integrity monitoring
- **Master authorized networks** — configurable API server access restriction
- **CI/CD auth** — Workload Identity Federation for GitHub Actions

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- Terraform >= 1.5

## Usage

### Deploy Infrastructure + ArgoCD

```bash
cd infra/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Set project_id and gitops_repo_url
terraform init
terraform plan
terraform apply
```

### Connect to the Cluster

```bash
$(terraform output -raw kubeconfig_command)
kubectl get nodes
```

### Access ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8443:443
# Open https://localhost:8443
# Username: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Access Kubeflow

After ArgoCD syncs all applications (10-15 minutes):

```bash
kubectl get applications -n argocd
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
# Open http://localhost:8080
# Default credentials: user@example.com / 12341234
```

### Upgrade Kubeflow

Change `targetRevision: v1.11.0` to the new version across files in `gitops/apps/kubeflow/`, commit, and push. ArgoCD syncs automatically.

### Enable/Disable Components

Edit `gitops/apps/kubeflow/kustomization.yaml` — uncomment or comment resource lines, commit, push. ArgoCD syncs.

## CI/CD

| Workflow | Trigger | Scope |
|---|---|---|
| `terraform.yml` | Push/PR to `main` on `infra/**` | fmt → validate → plan → apply |
| `terraform-destroy.yml` | Manual | confirm → plan destroy → destroy |
| `gitops-lint.yml` | Push/PR to `main` on `gitops/**` | Validate kustomize builds + YAML |

ArgoCD handles the actual deployment of gitops/ changes — no CI/CD pipeline needed for apply.

## Teardown

Via GitHub Actions:
1. **Actions → Terraform Destroy → Run workflow**
2. Type `destroy` to confirm

Locally:
```bash
cd infra/environments/dev
terraform destroy
```
