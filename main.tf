# 1. Gera os segredos
resource "talos_machine_secrets" "cluster_secrets" {}

# 2. Configuração do talosconfig cliente
data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  # Usa o nosso IP Fixo cravado na reserva de MAC
  endpoints = ["192.168.1.200"]
}

# 3. Inicia o banco de dados ETCD no primeiro nó (Cria o cluster de fato)
resource "talos_machine_bootstrap" "bootstrap" {
  # Depende da aplicação do control plane que já está no seu control-plane.tf
  depends_on = [talos_machine_configuration_apply.controlplane]

  node                 = "192.168.1.200"
  endpoint             = "192.168.1.200"
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
}

# 4. Gera o Kubeconfig
resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap]
  node                 = "192.168.1.200"
  endpoint             = "192.168.1.200"
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
}

# 5. Salva o kubeconfig apontando para o novo resource
resource "local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
