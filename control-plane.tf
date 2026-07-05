resource "proxmox_vm_qemu" "controlplane" {
  for_each    = local.controlplane_nodes
  vmid        = each.value.vmid
  name        = each.value.hostname
  target_node = var.target_node
  clone       = var.clone_template
  os_type     = var.vm_os_type
  tags        = local.proxmox_controlplane_tags

  define_connection_info    = false
  automatic_reboot          = var.vm_automatic_reboot
  automatic_reboot_severity = var.vm_automatic_reboot_severity

  agent         = 1
  agent_timeout = var.vm_agent_timeout
  skip_ipv6     = true

  boot         = "order=scsi0"
  scsihw       = "virtio-scsi-pci"
  memory       = coalesce(var.controlplane_vm_memory, var.vm_memory)
  ipconfig0    = "ip=${each.value.ip}/${var.network_prefix_length},gw=${var.network_gateway}"
  nameserver   = join(" ", var.network_nameservers)
  searchdomain = var.cluster_name

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

data "talos_machine_configuration" "controlplane" {
  cluster_name = var.cluster_name

  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets
  talos_version    = var.talos_version
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each                    = local.controlplane_nodes
  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  config_patches = concat(
    [local.controlplane_machine_patches[each.key]],
    [local.external_cloud_provider_patch],
    local.extension_service_patches_by_hostname[each.value.hostname],
  )
  apply_mode = "staged_if_needing_reboot"

  depends_on = [proxmox_vm_qemu.controlplane]

  node     = coalesce(each.value.bootstrap_ip, proxmox_vm_qemu.controlplane[each.key].default_ipv4_address, each.value.ip)
  endpoint = coalesce(each.value.bootstrap_ip, proxmox_vm_qemu.controlplane[each.key].default_ipv4_address, each.value.ip)
}
