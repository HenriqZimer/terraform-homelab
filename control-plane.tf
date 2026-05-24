resource "proxmox_vm_qemu" "controlplane" {
  count       = var.controlplane_count
  vmid        = 200 + count.index
  name        = "talos-cp-${count.index + 1}"
  target_node = var.target_node
  clone       = var.clone_template

  define_connection_info = false

  agent     = 1
  skip_ipv6 = true

  boot   = "order=scsi0"
  scsihw = "virtio-scsi-pci"
  memory = var.vm_memory

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
    id      = 0
    model   = "virtio"
    bridge  = var.vm_bridge
    macaddr = "BE:EF:00:00:02:0${count.index}"
  }

  timeouts {
    create = "2m"
  }

}

# 2. Configuração Dinâmica do Control Plane (Deixe APENAS esta versão)
data "talos_machine_configuration" "controlplane" {
  cluster_name = var.cluster_name

  # Pega o IP real obtido via DHCP na primeira VM control plane
  cluster_endpoint = "https://192.168.1.200:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  talos_version    = var.talos_version
}

resource "talos_machine_configuration_apply" "controlplane" {
  count                       = var.controlplane_count
  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration

  # ADICIONE A DEPENDÊNCIA: Só envia a configuração DEPOIS que a VM existir
  depends_on = [proxmox_vm_qemu.controlplane]

  node     = "192.168.1.${200 + count.index}"
  endpoint = "192.168.1.${200 + count.index}"
}
