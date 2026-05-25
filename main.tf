resource "talos_machine_secrets" "cluster_secrets" {}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  endpoints = [var.controlplane_ip]
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  node                 = var.controlplane_ip
  endpoint             = var.controlplane_ip
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  node                 = var.controlplane_ip
  endpoint             = var.controlplane_ip
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
}

resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
