####### Credenciais do Proxmox #######
variable "pm_api_url" {
  type        = string
  description = "URL da API do Proxmox"
}

variable "pm_api_token_id" {
  type        = string
  description = "ID do Token da API"
}

variable "pm_api_token_secret" {
  type        = string
  description = "Secret do Token da API"
  sensitive   = true
}

####### Configurações do Talos #######
variable "cloudflare_tunnel_token" {
  type        = string
  description = "Token do Tunnel do Cloudflare"
  sensitive   = true
}

variable "tailscale_auth_key" {
  type        = string
  description = "Auth Key do Tailscale para registrar o nó"
  sensitive   = true
}

variable "talos_installer_image" {
  type        = string
  description = "Imagem customizada do instalador do Talos gerada no Image Factory"
}

variable "talos_version" {
  type        = string
  default     = "v1.13.2"
  description = "Versão do Talos OS usada no template do Proxmox."
}

####### Configurações de Cluster e Rede #######
variable "network_gateway" {
  type        = string
  description = "Gateway da rede onde as VMs serão criadas."
}

variable "controlplane_ip" {
  type        = string
  description = "IP estático para o Control Plane"
}

variable "controlplane_count" {
  type        = number
  default     = 1
  description = "Quantidade de nodes control plane."

  validation {
    condition     = var.controlplane_count >= 1
    error_message = "controlplane_count deve ser >= 1."
  }
}

variable "worker_count" {
  type        = number
  default     = 0
  description = "Quantidade de nodes worker."

  validation {
    condition     = var.worker_count >= 0
    error_message = "worker_count deve ser >= 0."
  }
}

variable "cluster_name" {
  type        = string
  description = "Nome do Cluster Kubernetes."
}

variable "cluster_endpoint" {
  type        = string
  description = "Endpoint da API do Kubernetes (VIP ou IP do primeiro control plane)."
}

variable "target_node" {
  type        = string
  description = "Nome do node no Proxmox onde as VMs serão criadas."
}

variable "clone_template" {
  type        = string
  description = "Nome do template raw do Talos no Proxmox."
}

####### Configurações da VM #######
variable "vm_memory" {
  type        = number
  default     = 4096
  description = "Memória em MB por VM."
}

variable "vm_cores" {
  type        = number
  default     = 4
  description = "Quantidade de cores por VM."
}

variable "vm_sockets" {
  type        = number
  default     = 1
  description = "Quantidade de sockets por VM."
}

variable "vm_disk_size" {
  type        = string
  default     = "32G"
  description = "Tamanho do disco de cada VM."
}

variable "vm_storage" {
  type        = string
  default     = "local-lvm"
  description = "Storage do Proxmox para o disco da VM."
}

variable "vm_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Bridge de rede do Proxmox."
}
