# Core Kubeflow infrastructure: cert-manager issuer, namespace, roles, Istio resources,
# Knative, Dex, oauth2-proxy. These are always deployed when install_kubeflow = true.

# --- cert-manager kubeflow issuer ---
data "kustomization_build" "cert_manager_issuer" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/cert-manager/kubeflow-issuer/base"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "cert_manager_issuer_p0" {
  for_each   = local.kf ? data.kustomization_build.cert_manager_issuer[0].ids_prio[0] : []
  manifest   = data.kustomization_build.cert_manager_issuer[0].manifests[each.value]
  depends_on = [helm_release.cert_manager]
}

resource "kustomization_resource" "cert_manager_issuer_p1" {
  for_each   = local.kf ? data.kustomization_build.cert_manager_issuer[0].ids_prio[1] : []
  manifest   = data.kustomization_build.cert_manager_issuer[0].manifests[each.value]
  depends_on = [kustomization_resource.cert_manager_issuer_p0]
}

# --- Kubeflow namespace ---
data "kustomization_build" "kubeflow_namespace" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/kubeflow-namespace/base"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "kubeflow_namespace_p0" {
  for_each = local.kf ? data.kustomization_build.kubeflow_namespace[0].ids_prio[0] : []
  manifest = data.kustomization_build.kubeflow_namespace[0].manifests[each.value]
}

# --- Kubeflow roles ---
data "kustomization_build" "kubeflow_roles" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/kubeflow-roles/base"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "kubeflow_roles_p0" {
  for_each   = local.kf ? data.kustomization_build.kubeflow_roles[0].ids_prio[0] : []
  manifest   = data.kustomization_build.kubeflow_roles[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_namespace_p0]
}

resource "kustomization_resource" "kubeflow_roles_p1" {
  for_each   = local.kf ? data.kustomization_build.kubeflow_roles[0].ids_prio[1] : []
  manifest   = data.kustomization_build.kubeflow_roles[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p0]
}

# --- Istio Kubeflow resources ---
data "kustomization_build" "istio_kubeflow" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/istio/kubeflow-istio-resources/base"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "istio_kubeflow_p0" {
  for_each = local.kf ? data.kustomization_build.istio_kubeflow[0].ids_prio[0] : []
  manifest = data.kustomization_build.istio_kubeflow[0].manifests[each.value]
  depends_on = [
    helm_release.istiod,
    kustomization_resource.kubeflow_namespace_p0,
  ]
}

resource "kustomization_resource" "istio_kubeflow_p1" {
  for_each   = local.kf ? data.kustomization_build.istio_kubeflow[0].ids_prio[1] : []
  manifest   = data.kustomization_build.istio_kubeflow[0].manifests[each.value]
  depends_on = [kustomization_resource.istio_kubeflow_p0]
}

# --- Knative Serving (required for KServe and Kubeflow) ---
data "kustomization_build" "knative_serving" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/knative/knative-serving/overlays/gateways"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "knative_serving_p0" {
  for_each   = local.kf ? data.kustomization_build.knative_serving[0].ids_prio[0] : []
  manifest   = data.kustomization_build.knative_serving[0].manifests[each.value]
  depends_on = [helm_release.istio_ingressgateway]
}

resource "kustomization_resource" "knative_serving_p1" {
  for_each = local.kf ? data.kustomization_build.knative_serving[0].ids_prio[1] : []
  manifest = data.kustomization_build.knative_serving[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.knative_serving_p0]
}

resource "kustomization_resource" "knative_serving_p2" {
  for_each   = local.kf ? data.kustomization_build.knative_serving[0].ids_prio[2] : []
  manifest   = data.kustomization_build.knative_serving[0].manifests[each.value]
  depends_on = [kustomization_resource.knative_serving_p1]
}

# --- Knative Eventing (optional) ---
data "kustomization_build" "knative_eventing" {
  count      = local.enable_knative_eventing ? 1 : 0
  path       = "${local.m}/common/knative/knative-eventing/base"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "knative_eventing_p0" {
  for_each = local.enable_knative_eventing ? data.kustomization_build.knative_eventing[0].ids_prio[0] : []
  manifest = data.kustomization_build.knative_eventing[0].manifests[each.value]
}

resource "kustomization_resource" "knative_eventing_p1" {
  for_each = local.enable_knative_eventing ? data.kustomization_build.knative_eventing[0].ids_prio[1] : []
  manifest = data.kustomization_build.knative_eventing[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.knative_eventing_p0]
}

resource "kustomization_resource" "knative_eventing_p2" {
  for_each   = local.enable_knative_eventing ? data.kustomization_build.knative_eventing[0].ids_prio[2] : []
  manifest   = data.kustomization_build.knative_eventing[0].manifests[each.value]
  depends_on = [kustomization_resource.knative_eventing_p1]
}

# --- Dex (auth) ---
data "kustomization_build" "dex" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/dex/overlays/oauth2-proxy"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "dex_p0" {
  for_each = local.kf ? data.kustomization_build.dex[0].ids_prio[0] : []
  manifest = (
    contains(["_/Secret"], regex("(?P<group_kind>.*/.*)/.*/.*/.*", each.value)["group_kind"])
    ? sensitive(data.kustomization_build.dex[0].manifests[each.value])
    : data.kustomization_build.dex[0].manifests[each.value]
  )
  depends_on = [kustomization_resource.cert_manager_issuer_p1]
}

resource "kustomization_resource" "dex_p1" {
  for_each = local.kf ? data.kustomization_build.dex[0].ids_prio[1] : []
  manifest = (
    contains(["_/Secret"], regex("(?P<group_kind>.*/.*)/.*/.*/.*", each.value)["group_kind"])
    ? sensitive(data.kustomization_build.dex[0].manifests[each.value])
    : data.kustomization_build.dex[0].manifests[each.value]
  )
  wait = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.dex_p0]
}

# --- oauth2-proxy ---
data "kustomization_build" "oauth2_proxy" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/common/oauth2-proxy/overlays/m2m-dex-only"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "oauth2_proxy_p0" {
  for_each   = local.kf ? data.kustomization_build.oauth2_proxy[0].ids_prio[0] : []
  manifest   = data.kustomization_build.oauth2_proxy[0].manifests[each.value]
  depends_on = [kustomization_resource.dex_p1]
}

resource "kustomization_resource" "oauth2_proxy_p1" {
  for_each = local.kf ? data.kustomization_build.oauth2_proxy[0].ids_prio[1] : []
  manifest = data.kustomization_build.oauth2_proxy[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.oauth2_proxy_p0]
}

# --- Central Dashboard (always on when KF is enabled) ---
data "kustomization_build" "central_dashboard" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/applications/centraldashboard/overlays/oauth2-proxy"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "central_dashboard_p0" {
  for_each   = local.kf ? data.kustomization_build.central_dashboard[0].ids_prio[0] : []
  manifest   = data.kustomization_build.central_dashboard[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "central_dashboard_p1" {
  for_each = local.kf ? data.kustomization_build.central_dashboard[0].ids_prio[1] : []
  manifest = data.kustomization_build.central_dashboard[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.central_dashboard_p0]
}

# --- Admission Webhook (always on) ---
data "kustomization_build" "admission_webhook" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/applications/admission-webhook/upstream/overlays/cert-manager"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "admission_webhook_p0" {
  for_each   = local.kf ? data.kustomization_build.admission_webhook[0].ids_prio[0] : []
  manifest   = data.kustomization_build.admission_webhook[0].manifests[each.value]
  depends_on = [kustomization_resource.cert_manager_issuer_p1, kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "admission_webhook_p1" {
  for_each = local.kf ? data.kustomization_build.admission_webhook[0].ids_prio[1] : []
  manifest = data.kustomization_build.admission_webhook[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.admission_webhook_p0]
}

resource "kustomization_resource" "admission_webhook_p2" {
  for_each   = local.kf ? data.kustomization_build.admission_webhook[0].ids_prio[2] : []
  manifest   = data.kustomization_build.admission_webhook[0].manifests[each.value]
  depends_on = [kustomization_resource.admission_webhook_p1]
}

# --- Profiles + KFAM (always on) ---
data "kustomization_build" "profiles" {
  count      = local.kf ? 1 : 0
  path       = "${local.m}/applications/profiles/pss"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "profiles_p0" {
  for_each   = local.kf ? data.kustomization_build.profiles[0].ids_prio[0] : []
  manifest   = data.kustomization_build.profiles[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "profiles_p1" {
  for_each = local.kf ? data.kustomization_build.profiles[0].ids_prio[1] : []
  manifest = data.kustomization_build.profiles[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.profiles_p0]
}

resource "kustomization_resource" "profiles_p2" {
  for_each   = local.kf ? data.kustomization_build.profiles[0].ids_prio[2] : []
  manifest   = data.kustomization_build.profiles[0].manifests[each.value]
  depends_on = [kustomization_resource.profiles_p1]
}

# --- Default user namespace (optional) ---
data "kustomization_build" "user_namespace" {
  count      = local.enable_user_namespace ? 1 : 0
  path       = "${local.m}/common/user-namespace/base"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "user_namespace_p0" {
  for_each   = local.enable_user_namespace ? data.kustomization_build.user_namespace[0].ids_prio[0] : []
  manifest   = data.kustomization_build.user_namespace[0].manifests[each.value]
  depends_on = [kustomization_resource.profiles_p2]
}

resource "kustomization_resource" "user_namespace_p1" {
  for_each   = local.enable_user_namespace ? data.kustomization_build.user_namespace[0].ids_prio[1] : []
  manifest   = data.kustomization_build.user_namespace[0].manifests[each.value]
  depends_on = [kustomization_resource.user_namespace_p0]
}
