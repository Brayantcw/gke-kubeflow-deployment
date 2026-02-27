# Install ArgoCD via Helm — this is the only K8s workload Terraform manages.
# Once running, ArgoCD takes over all other cluster deployments via gitops/.

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = var.argocd_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  # Server config
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Disable dex — Kubeflow brings its own Dex
  set {
    name  = "dex.enabled"
    value = "false"
  }

  # Resource requests for the controller
  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }
}

# Root Application: tells ArgoCD to watch gitops/argocd/ for the app-of-apps pattern.
# ArgoCD discovers all child Applications from there and syncs them.
resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "kubeflow-platform"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_revision
        path           = var.gitops_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
