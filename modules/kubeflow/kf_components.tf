# Optional Kubeflow components — each gated by its own toggle variable.

# --- Kubeflow Pipelines ---
data "kustomization_build" "pipelines" {
  count      = local.enable_pipelines ? 1 : 0
  path       = "${local.m}/applications/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "pipelines_p0" {
  for_each = local.enable_pipelines ? data.kustomization_build.pipelines[0].ids_prio[0] : []
  manifest = data.kustomization_build.pipelines[0].manifests[each.value]
  depends_on = [
    kustomization_resource.kubeflow_roles_p1,
    kustomization_resource.istio_kubeflow_p1,
    kustomization_resource.cert_manager_issuer_p1,
  ]
}

resource "kustomization_resource" "pipelines_p1" {
  for_each = local.enable_pipelines ? data.kustomization_build.pipelines[0].ids_prio[1] : []
  manifest = (
    contains(["_/Secret"], regex("(?P<group_kind>.*/.*)/.*/.*/.*", each.value)["group_kind"])
    ? sensitive(data.kustomization_build.pipelines[0].manifests[each.value])
    : data.kustomization_build.pipelines[0].manifests[each.value]
  )
  wait = true
  timeouts {
    create = "10m"
    update = "10m"
  }
  depends_on = [kustomization_resource.pipelines_p0]
}

resource "kustomization_resource" "pipelines_p2" {
  for_each   = local.enable_pipelines ? data.kustomization_build.pipelines[0].ids_prio[2] : []
  manifest   = data.kustomization_build.pipelines[0].manifests[each.value]
  depends_on = [kustomization_resource.pipelines_p1]
}

# --- Katib ---
data "kustomization_build" "katib" {
  count      = local.enable_katib ? 1 : 0
  path       = "${local.m}/applications/katib/upstream/installs/katib-with-kubeflow"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "katib_p0" {
  for_each   = local.enable_katib ? data.kustomization_build.katib[0].ids_prio[0] : []
  manifest   = data.kustomization_build.katib[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "katib_p1" {
  for_each = local.enable_katib ? data.kustomization_build.katib[0].ids_prio[1] : []
  manifest = data.kustomization_build.katib[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.katib_p0]
}

resource "kustomization_resource" "katib_p2" {
  for_each   = local.enable_katib ? data.kustomization_build.katib[0].ids_prio[2] : []
  manifest   = data.kustomization_build.katib[0].manifests[each.value]
  depends_on = [kustomization_resource.katib_p1]
}

# --- Jupyter Notebooks ---
data "kustomization_build" "notebook_controller" {
  count      = local.enable_notebooks ? 1 : 0
  path       = "${local.m}/applications/jupyter/notebook-controller/upstream/overlays/kubeflow"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "notebook_controller_p0" {
  for_each   = local.enable_notebooks ? data.kustomization_build.notebook_controller[0].ids_prio[0] : []
  manifest   = data.kustomization_build.notebook_controller[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "notebook_controller_p1" {
  for_each = local.enable_notebooks ? data.kustomization_build.notebook_controller[0].ids_prio[1] : []
  manifest = data.kustomization_build.notebook_controller[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.notebook_controller_p0]
}

resource "kustomization_resource" "notebook_controller_p2" {
  for_each   = local.enable_notebooks ? data.kustomization_build.notebook_controller[0].ids_prio[2] : []
  manifest   = data.kustomization_build.notebook_controller[0].manifests[each.value]
  depends_on = [kustomization_resource.notebook_controller_p1]
}

data "kustomization_build" "jupyter_web_app" {
  count      = local.enable_notebooks ? 1 : 0
  path       = "${local.m}/applications/jupyter/jupyter-web-app/upstream/overlays/istio"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "jupyter_web_app_p0" {
  for_each   = local.enable_notebooks ? data.kustomization_build.jupyter_web_app[0].ids_prio[0] : []
  manifest   = data.kustomization_build.jupyter_web_app[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "jupyter_web_app_p1" {
  for_each = local.enable_notebooks ? data.kustomization_build.jupyter_web_app[0].ids_prio[1] : []
  manifest = data.kustomization_build.jupyter_web_app[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.jupyter_web_app_p0]
}

# --- Training Operator v2 (Trainer) ---
data "kustomization_build" "trainer" {
  count      = local.enable_training_operator ? 1 : 0
  path       = "${local.m}/applications/trainer/overlays"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "trainer_p0" {
  for_each   = local.enable_training_operator ? data.kustomization_build.trainer[0].ids_prio[0] : []
  manifest   = data.kustomization_build.trainer[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "trainer_p1" {
  for_each = local.enable_training_operator ? data.kustomization_build.trainer[0].ids_prio[1] : []
  manifest = data.kustomization_build.trainer[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.trainer_p0]
}

resource "kustomization_resource" "trainer_p2" {
  for_each   = local.enable_training_operator ? data.kustomization_build.trainer[0].ids_prio[2] : []
  manifest   = data.kustomization_build.trainer[0].manifests[each.value]
  depends_on = [kustomization_resource.trainer_p1]
}

# --- Tensorboard ---
data "kustomization_build" "tensorboard_controller" {
  count      = local.enable_tensorboard ? 1 : 0
  path       = "${local.m}/applications/tensorboard/tensorboard-controller/upstream/overlays/kubeflow"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "tensorboard_controller_p0" {
  for_each   = local.enable_tensorboard ? data.kustomization_build.tensorboard_controller[0].ids_prio[0] : []
  manifest   = data.kustomization_build.tensorboard_controller[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "tensorboard_controller_p1" {
  for_each = local.enable_tensorboard ? data.kustomization_build.tensorboard_controller[0].ids_prio[1] : []
  manifest = data.kustomization_build.tensorboard_controller[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.tensorboard_controller_p0]
}

data "kustomization_build" "tensorboard_web_app" {
  count      = local.enable_tensorboard ? 1 : 0
  path       = "${local.m}/applications/tensorboard/tensorboards-web-app/upstream/overlays/istio"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "tensorboard_web_app_p0" {
  for_each   = local.enable_tensorboard ? data.kustomization_build.tensorboard_web_app[0].ids_prio[0] : []
  manifest   = data.kustomization_build.tensorboard_web_app[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "tensorboard_web_app_p1" {
  for_each = local.enable_tensorboard ? data.kustomization_build.tensorboard_web_app[0].ids_prio[1] : []
  manifest = data.kustomization_build.tensorboard_web_app[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.tensorboard_web_app_p0]
}

# --- Volumes Web App ---
data "kustomization_build" "volumes_web_app" {
  count      = local.enable_volumes_web_app ? 1 : 0
  path       = "${local.m}/applications/volumes-web-app/upstream/overlays/istio"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "volumes_web_app_p0" {
  for_each   = local.enable_volumes_web_app ? data.kustomization_build.volumes_web_app[0].ids_prio[0] : []
  manifest   = data.kustomization_build.volumes_web_app[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "volumes_web_app_p1" {
  for_each = local.enable_volumes_web_app ? data.kustomization_build.volumes_web_app[0].ids_prio[1] : []
  manifest = data.kustomization_build.volumes_web_app[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.volumes_web_app_p0]
}

# --- KServe ---
data "kustomization_build" "kserve" {
  count      = local.enable_kserve ? 1 : 0
  path       = "${local.m}/applications/kserve/kserve"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "kserve_p0" {
  for_each   = local.enable_kserve ? data.kustomization_build.kserve[0].ids_prio[0] : []
  manifest   = data.kustomization_build.kserve[0].manifests[each.value]
  depends_on = [kustomization_resource.knative_serving_p2, kustomization_resource.cert_manager_issuer_p1]
}

resource "kustomization_resource" "kserve_p1" {
  for_each = local.enable_kserve ? data.kustomization_build.kserve[0].ids_prio[1] : []
  manifest = data.kustomization_build.kserve[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.kserve_p0]
}

resource "kustomization_resource" "kserve_p2" {
  for_each   = local.enable_kserve ? data.kustomization_build.kserve[0].ids_prio[2] : []
  manifest   = data.kustomization_build.kserve[0].manifests[each.value]
  depends_on = [kustomization_resource.kserve_p1]
}

data "kustomization_build" "kserve_models_web_app" {
  count      = local.enable_kserve ? 1 : 0
  path       = "${local.m}/applications/kserve/models-web-app/overlays/kubeflow"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "kserve_models_web_app_p0" {
  for_each   = local.enable_kserve ? data.kustomization_build.kserve_models_web_app[0].ids_prio[0] : []
  manifest   = data.kustomization_build.kserve_models_web_app[0].manifests[each.value]
  depends_on = [kustomization_resource.kserve_p2, kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "kserve_models_web_app_p1" {
  for_each = local.enable_kserve ? data.kustomization_build.kserve_models_web_app[0].ids_prio[1] : []
  manifest = data.kustomization_build.kserve_models_web_app[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.kserve_models_web_app_p0]
}

# --- Spark Operator ---
data "kustomization_build" "spark_operator" {
  count      = local.enable_spark_operator ? 1 : 0
  path       = "${local.m}/applications/spark/spark-operator/overlays/kubeflow"
  depends_on = [null_resource.clone_manifests]
}

resource "kustomization_resource" "spark_operator_p0" {
  for_each   = local.enable_spark_operator ? data.kustomization_build.spark_operator[0].ids_prio[0] : []
  manifest   = data.kustomization_build.spark_operator[0].manifests[each.value]
  depends_on = [kustomization_resource.kubeflow_roles_p1]
}

resource "kustomization_resource" "spark_operator_p1" {
  for_each = local.enable_spark_operator ? data.kustomization_build.spark_operator[0].ids_prio[1] : []
  manifest = data.kustomization_build.spark_operator[0].manifests[each.value]
  wait     = true
  timeouts {
    create = "5m"
    update = "5m"
  }
  depends_on = [kustomization_resource.spark_operator_p0]
}

resource "kustomization_resource" "spark_operator_p2" {
  for_each   = local.enable_spark_operator ? data.kustomization_build.spark_operator[0].ids_prio[2] : []
  manifest   = data.kustomization_build.spark_operator[0].manifests[each.value]
  depends_on = [kustomization_resource.spark_operator_p1]
}
