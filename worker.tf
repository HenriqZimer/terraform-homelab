resource "proxmox_vm_qemu" "worker" {
  count       = var.worker_count
  vmid        = 220 + count.index
  name        = "talos-worker-${count.index + 1}"
  target_node = var.target_node
  clone       = var.clone_template
  depends_on  = [proxmox_vm_qemu.controlplane]

  define_connection_info = false

  agent     = 1
  skip_ipv6 = true
  boot      = "order=scsi0"
  scsihw    = "virtio-scsi-pci"
  memory    = var.vm_memory

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

  network {
    id     = 0
    model  = "virtio"
    bridge = var.vm_bridge
    # MAC Fixo para os Workers (Terminando em 20, 21, 22...)
    macaddr = "BE:EF:00:00:02:2${count.index}"
  }

  timeouts {
    create = "2m"
  }

}

# 3. Configuração Dinâmica do Worker (Deixe APENAS esta versão)
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://192.168.1.200:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  talos_version    = var.talos_version
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = var.worker_count
  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration

  # ADICIONE A DEPENDÊNCIA: Só envia a configuração DEPOIS que o Worker existir
  depends_on = [proxmox_vm_qemu.worker]

  node     = "192.168.1.${220 + count.index}"
  endpoint = "192.168.1.${220 + count.index}"
}
