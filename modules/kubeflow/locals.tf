# Computed toggles: component is enabled only if both master toggle and per-component toggle are true
locals {
  kf = var.install_kubeflow

  enable_pipelines         = local.kf && var.enable_pipelines
  enable_notebooks         = local.kf && var.enable_notebooks
  enable_katib             = local.kf && var.enable_katib
  enable_kserve            = local.kf && var.enable_kserve
  enable_training_operator = local.kf && var.enable_training_operator
  enable_tensorboard       = local.kf && var.enable_tensorboard
  enable_volumes_web_app   = local.kf && var.enable_volumes_web_app
  enable_knative_eventing  = local.kf && var.enable_knative_eventing
  enable_spark_operator    = local.kf && var.enable_spark_operator
  enable_user_namespace    = local.kf && var.enable_user_namespace

  # v1.11 manifest paths (changed from apps/ to applications/)
  m = var.manifests_path
}
