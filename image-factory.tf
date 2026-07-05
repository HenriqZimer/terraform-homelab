resource "talos_image_factory_schematic" "extensions" {
  schematic = local.talos_image_schematic
}

data "talos_image_factory_urls" "extensions" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.extensions.id
  architecture  = var.talos_architecture
  platform      = var.talos_platform
}
