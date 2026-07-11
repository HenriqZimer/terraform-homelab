# kubectl e usado apenas para aguardar o node aparecer na API (nao ha
# resource nativo de "wait" no provider kubernetes). A mutacao em si -
# aplicar os labels - e feita pelo resource declarativo kubernetes_labels,
# que fica rastreado no state em vez de ser um efeito colateral de shell.
resource "terraform_data" "wait_for_worker_node" {
  for_each = local.worker_nodes

  triggers_replace = {
    kubeconfig = local_file.kubeconfig.id
    node       = each.value.hostname
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -uo pipefail
      # kubectl wait --for=create sai no primeiro erro de conexao (API
      # indisponivel), sem tolerar o control plane cair/reiniciar durante o
      # bootstrap. Faz polling manual para sobreviver a essas janelas.
      deadline=$((SECONDS + 600))
      until kubectl --kubeconfig '${local_file.kubeconfig.filename}' \
        get "node/${each.value.hostname}" >/dev/null 2>&1; do
        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "timeout esperando node/${each.value.hostname} aparecer na API" >&2
          exit 1
        fi
        sleep 5
      done
    EOT
  }

  depends_on = [
    local_file.kubeconfig,
    talos_cluster_kubeconfig.kubeconfig,
    talos_machine_configuration_apply.worker,
  ]
}

resource "kubernetes_labels" "worker" {
  for_each = local.worker_nodes

  api_version = "v1"
  kind        = "Node"
  force       = true

  metadata {
    name = each.value.hostname
  }

  labels = var.kubernetes_worker_labels

  depends_on = [terraform_data.wait_for_worker_node]
}
