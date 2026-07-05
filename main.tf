resource "talos_machine_secrets" "cluster_secrets" {
  talos_version = var.talos_version

  lifecycle {
    prevent_destroy = true
  }
}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  endpoints = [for node in values(local.controlplane_nodes) : node.ip]
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  node                 = local.controlplane_ip
  endpoint             = local.controlplane_ip
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  node                 = local.controlplane_ip
  endpoint             = local.controlplane_ip
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
}

resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename = "${path.module}/configs/kubeconfig"
}

resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.talosconfig.talos_config
  filename = "${path.module}/configs/talosconfig"
}

resource "local_sensitive_file" "karpenter_talos_worker_user_data" {
  content  = data.talos_machine_configuration.karpenter_worker.machine_configuration
  filename = "${path.module}/configs/karpenter-talos-worker-user-data.yaml"
}

check "controlplane_ha" {
  assert {
    condition     = var.controlplane_count == 1 || var.controlplane_vip != ""
    error_message = "controlplane_count > 1 sem controlplane_vip: nao ha um endpoint estavel para a API do Kubernetes sobreviver a perda do primeiro control plane. Defina controlplane_vip para HA real."
  }
}
