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

# O bootstrap so exige que o apid do Talos responda (servico nativo do OS),
# nao que o kube-apiserver ja esteja rodando - kubelet/etcd/kube-apiserver
# sao imagens containerd separadas, ainda por puxar nesse ponto. Se os
# workers comecarem a aplicar config (e portanto a puxar a propria imagem do
# kubelet) ao mesmo tempo que o control plane ainda esta puxando as dele, os
# dois pulls concorrem pelo mesmo link WAN - em links limitados isso pode
# levar timeouts de TLS que nao acontecem testando um node por vez. Espera o
# kube-apiserver do control plane responder antes de liberar os workers,
# serializando a etapa mais pesada de rede.
resource "terraform_data" "wait_for_controlplane_api" {
  triggers_replace = {
    bootstrap = talos_machine_bootstrap.bootstrap.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -uo pipefail
      node="${local.controlplane_ip}"
      deadline=$((SECONDS + 1200))
      until timeout 3 bash -c "echo >/dev/tcp/$node/6443" 2>/dev/null; do
        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "timeout esperando kube-apiserver em $node:6443" >&2
          exit 1
        fi
        sleep 5
      done
    EOT
  }

  depends_on = [talos_machine_bootstrap.bootstrap]
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
