---
title: "Production-Ready Kubeflow on GKE: A GitOps Approach with Terraform and ArgoCD"
date: 2026-02-27T12:00:00-00:00
draft: false
tags: ["kubeflow", "kubernetes", "gke", "terraform", "argocd", "gitops", "mlops", "machine-learning", "google-cloud", "devops"]
categories: ["mlops", "devops"]
author: "Brayant Torres"
description: "Deploying Kubeflow on GKE can be intimidating. In this post, I break down a production-grade solution that uses Terraform to provision infrastructure and ArgoCD to manage everything inside the cluster — so you never have to run kubectl apply manually again."
cover:
    image: "<image path/url>"
    alt: "<alt text>"
    caption: "<text>"
    relative: false
    hidden: true
showToc: true
TocOpen: false
hidemeta: false
comments: false
disableHLJS: false
disableShare: false
hideSummary: false
searchHidden: false
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowWordCount: true
ShowRssButtonInSectionTermList: true
UseHugoToc: true
editPost:
    URL: "https://github.com/brayantcw/brayantcw/edit/main/content"
    Text: "Suggest Changes"
    appendFilePath: true
---

# Production-Ready Kubeflow on GKE: A GitOps Approach with Terraform and ArgoCD

If you have ever tried to deploy Kubeflow from scratch, you know the pain. Dozens of YAML files, mysterious CRD ordering issues, Istio conflicts, authentication layers stacked on top of each other, and a manual process that is nearly impossible to reproduce consistently. Most tutorials show you how to get something running locally, but they rarely show you how to build something you would actually trust in production.

In this post, I walk through a solution that tackles exactly that problem: a fully automated, GitOps-driven Kubeflow deployment on Google Kubernetes Engine. The idea is simple — **Terraform provisions the cloud infrastructure, ArgoCD takes over everything inside the cluster**. You commit a change to Git, and the cluster converges to the desired state automatically. No manual `kubectl apply`, no configuration drift, no snowflake clusters.

Let me show you how this architecture works and how to deploy it yourself.

## Why This Is Harder Than It Looks

Kubeflow is not a single application. It is a platform composed of many loosely coupled components: Istio for the service mesh, cert-manager for TLS, Dex for OIDC authentication, oauth2-proxy as the authentication reverse proxy, Knative Serving, and then the actual ML workloads like Pipelines, Notebooks, Katib, and the Training Operator. Each of these has its own Custom Resource Definitions (CRDs), its own dependencies, and its own readiness timing.

Install them in the wrong order and you get cryptic errors. Install them all at once and some resources will fail because the CRDs they depend on are not registered yet. This is the core challenge that makes Kubeflow deployments brittle.

The solution is a deployment sequencing mechanism — and that is exactly what ArgoCD's sync waves give us.

## Architecture Overview

The repository is organized into two distinct layers:

```
gke-kubeflow-deployment/
├── infra/                  # Layer 1: Terraform (cloud infrastructure)
│   ├── modules/
│   │   ├── network/        # VPC, subnets, Cloud NAT
│   │   ├── gke/            # Private GKE cluster
│   │   ├── iam/            # Service accounts, Workload Identity
│   │   └── argocd-bootstrap/  # Installs ArgoCD and seeds root Application
│   └── environments/dev/   # Environment entry point
│
└── gitops/                 # Layer 2: ArgoCD (in-cluster workloads)
    ├── argocd/             # App-of-Apps root definition
    └── apps/
        ├── istio/          # Service mesh
        ├── cert-manager/   # TLS certificates
        └── kubeflow/       # ML platform (base + optional components)
```

**Layer 1** (Terraform) runs once to create the VPC, the private GKE cluster, IAM service accounts, and to install ArgoCD itself via Helm. Terraform's job ends there.

**Layer 2** (ArgoCD) watches the `gitops/` directory in the repository. As soon as it detects the root Application definition, it starts reconciling every component declared in Git. From that point forward, any change you make to the `gitops/` directory is automatically applied to the cluster.

This separation is intentional. Terraform manages cloud resources that live outside Kubernetes. ArgoCD manages everything that lives inside Kubernetes. Each tool does what it is best at.

## The Sync Wave Strategy

The most important design decision in this project is the use of ArgoCD sync waves to enforce deployment ordering. Here is how the waves are structured:

| Wave | Components | Why This Order |
|------|-----------|----------------|
| 1 | istio-base, cert-manager | CRDs must be registered first |
| 2 | istiod, Istio VirtualServices | Control plane needs CRDs from wave 1 |
| 3 | Istio Ingress Gateway, Dex, oauth2-proxy, Kubeflow namespace and roles | Gateway and auth need the mesh running |
| 4 | Central Dashboard, admission webhook, profiles | Core UI needs auth layer ready |
| 5 | Pipelines, Notebooks, Katib, Training Operator, TensorBoard | ML components depend on everything above |

Without this ordering, deployments are non-deterministic. With it, the cluster bootstraps itself reliably every time. Each wave only starts after all resources in the previous wave are healthy.

## Infrastructure Deep Dive

### Private GKE Cluster

The cluster is configured as a private cluster — nodes have no public IP addresses and communicate with the internet through Cloud NAT. The Kubernetes API server has a public endpoint (which you can lock down via `master_authorized_networks`) but the nodes themselves are completely isolated from inbound internet traffic.

```hcl
module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 43.0"

  project_id         = var.project_id
  name               = var.cluster_name
  region             = var.region
  network            = module.network.network_name
  subnetwork         = module.network.subnets_names[0]

  node_pools = [{
    name         = "default-node-pool"
    machine_type = "e2-standard-4"
    min_count    = 1
    max_count    = 3
    spot         = true   # 60-91% cost savings
  }]
}
```

The node pool uses **Spot VMs** by default. For a development or staging Kubeflow environment, this is a significant cost optimization — you get the same compute at a fraction of the price. For production, you would set `spot = false`.

### Workload Identity

Rather than mounting service account keys as Kubernetes secrets (a security antipattern), the cluster uses **GCP Workload Identity**. This allows Kubernetes service accounts to impersonate GCP service accounts, so Kubeflow Pipelines can write artifacts to Cloud Storage without any credential files in your pods.

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id              = var.project_id
  enable_kfp_sa           = true   # Creates pipelines service account
  kfp_k8s_namespace       = "kubeflow"
  kfp_k8s_sa_name         = "pipeline-runner"
}
```

### ArgoCD Bootstrap

This is the bridge between Terraform and GitOps. After provisioning the cluster, Terraform installs ArgoCD via Helm and then creates a single Kubernetes resource: the root ArgoCD Application that points to the `gitops/argocd/` directory in this repository.

```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.8"
  namespace  = "argocd"

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}
```

Once this root Application is created, ArgoCD discovers the child Applications (`app-istio.yaml`, `app-cert-manager.yaml`, `app-kubeflow.yaml`) and begins the sync wave sequence. Terraform's work is done.

## GitOps Layer: App-of-Apps Pattern

The `gitops/argocd/` directory implements the **App-of-Apps pattern**: a single ArgoCD Application that manages other ArgoCD Applications. This is the standard way to bootstrap a full platform with ArgoCD.

```yaml
# gitops/argocd/app-kubeflow.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  source:
    repoURL: https://github.com/your-org/gke-kubeflow-deployment
    path: gitops/apps/kubeflow
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 30s
        maxDuration: 5m
        factor: 2
```

The `selfHeal: true` flag means if someone manually changes something in the cluster, ArgoCD will revert it to match Git. The `prune: true` flag means if you remove a resource from Git, ArgoCD removes it from the cluster. This is true GitOps: Git is the single source of truth.

## Kubeflow Components: What Is Enabled

The deployment uses Kubeflow v1.11.0 manifests from the official `kubeflow/manifests` repository. Here is what is enabled by default:

| Component | Purpose |
|-----------|---------|
| Central Dashboard | Web UI and entry point |
| Pipelines | ML workflow orchestration |
| Notebooks | Jupyter notebook environments |
| Katib | Hyperparameter tuning |
| Training Operator | Distributed training (PyTorch, TensorFlow) |
| TensorBoard | Model visualization |
| Volumes Web App | PVC management UI |

And what is optionally available but disabled:

| Component | When to Enable |
|-----------|---------------|
| KServe | When you need model inference serving |
| Knative Eventing | Event-driven ML pipelines |
| Spark Operator | Large-scale data processing |

Enabling or disabling a component is a one-line change in `gitops/apps/kubeflow/kustomization.yaml`. Commit, push, and ArgoCD handles the rest.

## Step-by-Step Deployment

### Prerequisites

- GCP project with billing enabled
- `gcloud` CLI configured: `gcloud auth application-default login`
- Terraform >= 1.5
- `kubectl` installed

### Step 1: Configure Variables

```bash
cd infra/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project_id      = "your-gcp-project-id"
region          = "us-central1"
cluster_name    = "kubeflow-cluster"
gitops_repo_url = "https://github.com/your-org/gke-kubeflow-deployment.git"
```

The `gitops_repo_url` is what ArgoCD will watch. If you forked the repository, point it to your fork.

### Step 2: Deploy Infrastructure

```bash
terraform init
terraform plan   # Review what will be created
terraform apply  # Type 'yes' to confirm
```

Terraform will create:
- VPC with private subnets and secondary ranges for pods/services
- Cloud Router and Cloud NAT for outbound connectivity
- Private GKE cluster with 1 node (auto-scales to 3)
- IAM service accounts with least-privilege roles
- ArgoCD installed and seeded with the root Application

This takes about 10-15 minutes.

### Step 3: Connect to the Cluster

```bash
# Get the kubeconfig command from Terraform output
$(terraform output -raw kubeconfig_command)

# Verify connectivity
kubectl get nodes
```

### Step 4: Watch ArgoCD Sync

```bash
# Port-forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Open `https://localhost:8443`, log in with username `admin` and the password above. You will see all the Applications being created and synced in real time, wave by wave.

Alternatively, monitor from the command line:

```bash
kubectl get applications -n argocd -w
```

Wait until all Applications show `Synced` and `Healthy` status. This takes another 10-15 minutes as Kubeflow pulls images and starts pods.

### Step 5: Access Kubeflow

```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

Open `http://localhost:8080` and log in with:
- **Email**: `user@example.com`
- **Password**: `12341234`

You now have a fully functional Kubeflow installation with Pipelines, Notebooks, Katib, and TensorBoard.

> **Important**: Change the default credentials before exposing this to any network. Edit the Dex configuration in `gitops/apps/kubeflow/base/dex.yaml`.

## CI/CD: Automating the Full Lifecycle

The repository includes three GitHub Actions workflows:

**`terraform.yml`** — Runs on every push to `main` that touches `infra/**`:
1. `terraform fmt` — Format check
2. `terraform validate` — Syntax and dependency validation
3. `terraform plan` — Shows what would change
4. `terraform apply` — Applies on merge to `main` (requires approval gate)

**`gitops-lint.yml`** — Runs on every push that touches `gitops/**`:
1. Validates all Kustomize builds: `kustomize build gitops/argocd/`
2. Validates YAML syntax across all manifests
3. ArgoCD auto-syncs on success (no explicit apply step needed)

**`terraform-destroy.yml`** — Manual trigger only, requires typing "destroy" as confirmation. Has a separate approval gate to prevent accidents.

Authentication to GCP uses **Workload Identity Federation** — no service account keys are stored in GitHub secrets. This is the recommended approach for GitHub Actions with GCP.

## Day-2 Operations

One of the biggest advantages of this architecture is how simple ongoing operations become.

### Upgrading Kubeflow

Change the `targetRevision` in the relevant Application YAML:

```yaml
# gitops/argocd/app-kubeflow.yaml
spec:
  source:
    targetRevision: v1.12.0  # was v1.11.0
```

Commit, push. ArgoCD detects the change and rolls out the upgrade with its retry and backoff policy. No manual intervention required.

### Enabling a New Component

Uncomment the component in `gitops/apps/kubeflow/kustomization.yaml`:

```yaml
resources:
  # ...existing components...
  - components/kserve.yaml   # just uncomment this line
```

Commit, push. Done.

### Scaling the Cluster

The node pool is configured with `min_count = 1` and `max_count = 3`. GKE's cluster autoscaler handles scaling automatically based on pod resource requests. For heavier workloads, update the Terraform variables and run `terraform apply`.

## Security Considerations

A few things worth calling out explicitly:

**Private cluster**: Nodes have no public IPs. All outbound traffic goes through Cloud NAT. There is no inbound path from the internet to the nodes.

**Shielded nodes**: Secure boot and integrity monitoring are enabled, protecting against rootkit and bootkit attacks.

**Least-privilege service accounts**: The node service account has only the roles it needs — log writer, metric writer, and Artifact Registry reader. The Kubeflow Pipelines service account has only storage access via Workload Identity.

**No exported credentials**: GitHub Actions uses Workload Identity Federation. Pods use Workload Identity. No service account key files exist anywhere in this setup.

**Authentication layers**: Kubeflow sits behind Istio's ingress gateway, then oauth2-proxy (which enforces OIDC login), then Dex (the OIDC provider). Unauthenticated requests never reach Kubeflow.

## Wrapping Up

Setting up Kubeflow the right way requires solving several hard problems simultaneously: cloud infrastructure provisioning, Kubernetes cluster configuration, service mesh setup, certificate management, authentication, and finally the ML platform itself. Without a structured approach, this quickly becomes a tangle of imperative scripts that only the person who wrote them can maintain.

The architecture described here separates these concerns cleanly. Terraform owns the cloud layer. ArgoCD owns the cluster layer. Git owns the desired state. Each piece is independently understandable, testable, and upgradeable.

The full code is available at [github.com/Brayantcw/gke-kubeflow-deployment](https://github.com/Brayantcw/gke-kubeflow-deployment). Fork it, point it at your GCP project, and you will have a production-ready Kubeflow platform running in under 30 minutes.

---

*Have questions or ran into issues? Feel free to open an issue on the repository or reach out on LinkedIn.*
