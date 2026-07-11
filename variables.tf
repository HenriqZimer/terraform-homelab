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

variable "proxmox_region" {
  type        = string
  default     = "pve"
  description = "Regiao/cluster Proxmox usada no providerID (proxmox://<regiao>/<vmid>) que o kubelet declara via --provider-id para o proxmox-cloud-controller-manager. Deve bater com o region do secret proxmox-credentials e com o PROXMOX_REGION do helm-k8s-homelab."
}

####### Configurações do Talos #######
variable "talos_version" {
  type        = string
  default     = "v1.13.2"
  description = "Versão do Talos OS usada no template do Proxmox."
}

variable "talos_architecture" {
  type        = string
  default     = "amd64"
  description = "Arquitetura usada pelo Talos Image Factory."
}

variable "talos_platform" {
  type        = string
  default     = "nocloud"
  description = "Plataforma usada pelo Talos Image Factory para gerar os artefatos."
}

variable "talos_system_extensions" {
  type        = list(string)
  default     = ["siderolabs/tailscale", "siderolabs/cloudflared", "siderolabs/qemu-guest-agent"]
  description = "System extensions oficiais adicionadas ao schematic do Talos Image Factory."
}

variable "tailscale_auth_key" {
  type        = string
  default     = ""
  description = "Auth key ou OAuth client secret (tskey-client-...) do Tailscale usada pela system extension. Deixe vazio para nao configurar tailscaled. Prefira um OAuth client secret: ele funciona como key reusavel automaticamente, evitando falha quando varios nodes usam a mesma credencial."
  sensitive   = true
}

variable "tailscale_ephemeral" {
  type        = bool
  default     = false
  description = "Define se os nodes registrados via OAuth client secret aparecem como ephemeral no tailnet. Nodes de um cluster Talos devem ser persistentes, por isso o default e false."
}

variable "tailscale_tags" {
  type        = list(string)
  default     = []
  description = "Tags do OAuth client (ex: [\"tag:k8s\"]) usadas em --advertise-tags. So se aplica quando tailscale_auth_key e um OAuth client secret (tskey-client-...): sem tags nesse caso o tailscaled falha com 'oauth authkeys require --advertise-tags'. Ignorado para auth keys normais (tskey-auth-...), que ja tem tags definidas na criacao."
}

variable "tailscale_routes" {
  type        = list(string)
  default     = []
  description = "Rotas anunciadas pelo tailscaled, por exemplo o CIDR de services do Kubernetes."
}

variable "tailscale_accept_dns" {
  type        = bool
  default     = false
  description = "Define TS_ACCEPT_DNS para o tailscaled."
}

variable "tailscale_auth_once" {
  type        = bool
  default     = true
  description = "Define TS_AUTH_ONCE para evitar relogar a cada restart quando ja houver estado."
}

variable "cloudflared_tunnel_token" {
  type        = string
  default     = ""
  description = "Token do Cloudflare Tunnel usado pela system extension. Deixe vazio para nao configurar cloudflared."
  sensitive   = true
}

variable "cloudflared_metrics" {
  type        = string
  default     = "localhost:2000"
  description = "Endereco de metricas do cloudflared."
}

variable "cloudflared_edge_ip_version" {
  type        = string
  default     = "auto"
  description = "Versao de IP usada pelo cloudflared nas conexoes de edge."
}

####### Configurações de Cluster e Rede #######
variable "network_gateway" {
  type        = string
  description = "Gateway da rede onde as VMs serão criadas."
}

variable "node_network_prefix" {
  type        = string
  default     = ""
  description = "Prefixo IPv4 dos nodes, como 192.168.1. Se vazio, deriva dos tres primeiros octetos de network_gateway."
}

variable "network_prefix_length" {
  type        = number
  default     = 24
  description = "Prefixo CIDR usado nos IPs estaticos dos nodes Talos."

  validation {
    condition     = var.network_prefix_length > 0 && var.network_prefix_length <= 32
    error_message = "network_prefix_length deve estar entre 1 e 32."
  }
}

variable "network_nameservers" {
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
  description = "Servidores DNS configurados nos nodes Talos."
}

variable "talos_network_interface" {
  type        = string
  default     = "eth0"
  description = "Interface de rede configurada estaticamente no Talos."
}

variable "talos_network_mtu" {
  type        = number
  default     = 1500
  description = "MTU da interface de rede dos nodes Talos. Reduza (ex: 1492) se o link WAN usar PPPoE ou outro encapsulamento que reduza o MTU efetivo abaixo de 1500 - sem isso, pacotes grandes com DF set podem cair em um PMTU blackhole (handshakes pequenos funcionam, pulls de imagem grandes travam com connection reset) quando o ICMP 'fragmentation needed' do gateway nao chega de volta ate a VM."
}

variable "controlplane_ip" {
  type        = string
  default     = null
  description = "Override opcional do IP estatico do primeiro control plane. Se vazio, deriva de network_gateway + controlplane_vmid_start."
}

variable "controlplane_vip" {
  type        = string
  default     = ""
  description = "IP virtual (VIP) compartilhado pela API do Kubernetes entre os control planes. O Talos gerencia o failover nativamente via eleicao em etcd, sem precisar de keepalived. Obrigatorio para HA real quando controlplane_count > 1; deve ser um IP livre na mesma rede dos nodes."
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

variable "controlplane_bootstrap_ips" {
  type        = list(string)
  default     = []
  description = "IPs temporarios para aplicar a primeira machine config dos control planes quando eles ainda sobem por DHCP."
}

variable "worker_bootstrap_ips" {
  type        = list(string)
  default     = []
  description = "IPs temporarios para aplicar a primeira machine config dos workers quando eles ainda sobem por DHCP."
}

variable "cluster_name" {
  type        = string
  description = "Nome do Cluster Kubernetes."
}

variable "cluster_endpoint" {
  type        = string
  default     = null
  description = "Override opcional do endpoint da API Kubernetes. Se vazio, usa https://<controlplane_ip>:6443."
}

variable "target_node" {
  type        = string
  description = "Nome do node no Proxmox onde as VMs serão criadas."
}

variable "clone_template" {
  type        = string
  description = "Nome do template raw do Talos no Proxmox."
}

variable "vm_os_type" {
  type        = string
  default     = "cloud-init"
  description = "Tipo de OS usado pelo provider Proxmox. Use cloud-init para expor ipconfig0 ao Talos NoCloud."
}

variable "vm_agent_timeout" {
  type        = number
  default     = 300
  description = "Tempo, em segundos, para aguardar o QEMU Guest Agent reportar IP."
}

variable "vm_automatic_reboot" {
  type        = bool
  default     = false
  description = "Permite que o provider Proxmox reinicie VMs automaticamente ao mudar parametros que exigem reboot."
}

variable "vm_automatic_reboot_severity" {
  type        = string
  default     = "warning"
  description = "Severidade usada pelo provider Proxmox quando uma mudanca indica reboot necessario."

  validation {
    condition     = contains(["error", "warning"], var.vm_automatic_reboot_severity)
    error_message = "vm_automatic_reboot_severity deve ser error ou warning."
  }
}

variable "proxmox_common_tags" {
  type        = list(string)
  default     = ["k8s", "talos-os"]
  description = "Tags comuns aplicadas nas VMs do Proxmox."
}

variable "proxmox_controlplane_tags" {
  type        = list(string)
  default     = ["control-plane"]
  description = "Tags adicionais aplicadas nas VMs control plane do Proxmox."
}

variable "proxmox_worker_tags" {
  type        = list(string)
  default     = ["worker"]
  description = "Tags adicionais aplicadas nas VMs worker do Proxmox."
}

variable "kubernetes_worker_labels" {
  type        = map(string)
  default     = { "node-role.kubernetes.io/worker" = "" }
  description = "Labels Kubernetes aplicadas nos nodes worker via kubectl apos o bootstrap."
}

variable "controlplane_vmid_start" {
  type        = number
  default     = 200
  description = "VMID inicial dos control planes no Proxmox. Tambem define o ultimo octeto do IP estatico."

  validation {
    condition     = var.controlplane_vmid_start > 0 && var.controlplane_vmid_start < 255
    error_message = "controlplane_vmid_start deve estar entre 1 e 254 para tambem ser usado como ultimo octeto do IP."
  }
}

variable "vm_cloudinit_storage" {
  type        = string
  default     = "local-lvm"
  description = "Storage do Proxmox para o disco Cloud-Init/NoCloud usado para entregar ipconfig0 ao Talos."
}

variable "worker_vmid_start" {
  type        = number
  default     = 210
  description = "VMID inicial dos workers no Proxmox. Tambem define o ultimo octeto do IP estatico."

  validation {
    condition     = var.worker_vmid_start > 0 && var.worker_vmid_start < 255
    error_message = "worker_vmid_start deve estar entre 1 e 254 para tambem ser usado como ultimo octeto do IP."
  }
}

variable "controlplane_mac_prefix" {
  type        = string
  default     = "BE:EF:00:00:02"
  description = "Prefixo MAC usado nos control planes; o último byte é gerado pelo Terraform."
}

variable "worker_mac_prefix" {
  type        = string
  default     = "BE:EF:00:00:22"
  description = "Prefixo MAC usado nos workers; o último byte é gerado pelo Terraform."
}

####### Configurações da VM #######
variable "vm_memory" {
  type        = number
  default     = 4096
  description = "Memória em MB por VM (workers). Tambem usado como default do control plane se controlplane_vm_memory nao for definido."
}

variable "controlplane_vm_memory" {
  type        = number
  default     = null
  description = "Override opcional de memoria (MB) so para as VMs de control plane. O control plane roda etcd + kube-apiserver e tende a precisar de mais memoria que os workers; se vazio, usa vm_memory."
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

variable "vm_create_timeout" {
  type        = string
  default     = "5m"
  description = "Timeout para criacao/clonagem da VM no Proxmox. Deve ser >= vm_agent_timeout para nao falhar antes do agente reportar IP."
}

variable "pm_tls_insecure" {
  type        = bool
  default     = true
  description = "Ignora validacao do certificado TLS da API do Proxmox. Defina false se o Proxmox tiver certificado valido."
}
