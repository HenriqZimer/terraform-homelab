resource "proxmox_vm_qemu" "worker" {
  for_each    = local.worker_nodes
  vmid        = each.value.vmid
  name        = each.value.hostname
  target_node = var.target_node
  clone       = var.clone_template
  depends_on  = [proxmox_vm_qemu.controlplane]
  os_type     = var.vm_os_type
  tags        = local.proxmox_worker_tags

  define_connection_info    = false
  automatic_reboot          = var.vm_automatic_reboot
  automatic_reboot_severity = var.vm_automatic_reboot_severity

  agent         = 1
  agent_timeout = var.vm_agent_timeout
  skip_ipv6     = true
  boot          = "order=scsi0"
  scsihw        = "virtio-scsi-pci"
  memory        = var.vm_memory
  ipconfig0     = "ip=${each.value.ip}/${var.network_prefix_length},gw=${var.network_gateway}"
  nameserver    = join(" ", var.network_nameservers)
  searchdomain  = var.cluster_name

  cpu {
    cores   = var.vm_cores
    sockets = var.vm_sockets
  }

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.vm_storage
    size    = var.vm_disk_size
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = var.vm_cloudinit_storage
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = var.vm_bridge
    macaddr = each.value.mac
  }

  timeouts {
    create = var.vm_create_timeout
  }

  lifecycle {
    ignore_changes = [
      automatic_reboot,
      desc,
      disk,
      network,
      startup_shutdown,
      vm_state,
    ]
  }
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  talos_version    = var.talos_version
}

data "talos_machine_configuration" "karpenter_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  talos_version    = var.talos_version
  config_patches   = [local.external_cloud_provider_patch]
}

# Ver comentario equivalente em control-plane.tf sobre por que esse wait e
# necessario antes do primeiro talos_machine_configuration_apply.
resource "terraform_data" "wait_for_worker_apid" {
  for_each = local.worker_nodes

  triggers_replace = {
    vmid = proxmox_vm_qemu.worker[each.key].vmid
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -uo pipefail
      node="${local.worker_apply_endpoint[each.key]}"
      deadline=$((SECONDS + 300))
      until timeout 3 bash -c "echo >/dev/tcp/$node/50000" 2>/dev/null; do
        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "timeout esperando apid (porta 50000) em $node" >&2
          exit 1
        fi
        sleep 5
      done
    EOT
  }

  depends_on = [proxmox_vm_qemu.worker]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each             = local.worker_nodes
  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration

  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  config_patches = concat(
    [local.worker_machine_patches[each.key]],
    [local.external_cloud_provider_patch],
    local.extension_service_patches_by_hostname[each.value.hostname],
  )
  apply_mode = "staged_if_needing_reboot"

  depends_on = [terraform_data.wait_for_worker_apid]

  node     = local.worker_apply_endpoint[each.key]
  endpoint = local.worker_apply_endpoint[each.key]
}
