# --- Istio (via Helm) ---

resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_version
  namespace        = "istio-system"
  create_namespace = true

  set {
    name  = "defaultRevision"
    value = "default"
  }
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  set {
    name  = "pilot.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "pilot.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "cni.enabled"
    value = "false"
  }

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingressgateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-system"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  depends_on = [helm_release.istiod]
}

# --- cert-manager (via Helm) ---

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
}

# --- Clone Kubeflow manifests ---

resource "null_resource" "clone_manifests" {
  count = var.install_kubeflow ? 1 : 0

  triggers = {
    version = var.kubeflow_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      MANIFESTS_DIR="${var.manifests_path}"
      if [ ! -d "$MANIFESTS_DIR/.git" ]; then
        git clone --branch ${var.kubeflow_version} --depth 1 \
          https://github.com/kubeflow/manifests.git "$MANIFESTS_DIR"
      fi
    EOT
  }
}
