output "talos_image_factory_schematic_id" {
  description = "ID do schematic Talos Image Factory com as system extensions configuradas."
  value       = talos_image_factory_schematic.extensions.id
}

output "talos_image_factory_urls" {
  description = "URLs de artefatos Talos gerados para criar/atualizar o template no Proxmox."
  value       = data.talos_image_factory_urls.extensions.urls
}

output "talos_installer_image" {
  description = "Imagem installer do Talos Image Factory usada para upgrade dos nodes existentes."
  value       = data.talos_image_factory_urls.extensions.urls.installer
}

output "controlplane_nodes" {
  description = "Mapa de VMID e IP dos control planes."
  value       = local.controlplane_nodes
}

output "worker_nodes" {
  description = "Mapa de VMID e IP dos workers."
  value       = local.worker_nodes
}
