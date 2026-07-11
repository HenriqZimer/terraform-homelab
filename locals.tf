locals {
  network_gateway_parts = split(".", var.network_gateway)
  node_network_prefix   = var.node_network_prefix != "" ? var.node_network_prefix : join(".", slice(local.network_gateway_parts, 0, 3))

  # Maps chaveados por hostname (nao listas por indice): permitem for_each nos
  # resources de VM/config, para que remover ou trocar um node afete so aquele
  # node no plan, em vez de recriar todos os nodes com indice maior por causa
  # do deslocamento de posicao no count.
  controlplane_nodes = {
    for index in range(var.controlplane_count) : "talos-cp-${index + 1}" => {
      vmid = var.controlplane_vmid_start + index
      ip   = "${local.node_network_prefix}.${var.controlplane_vmid_start + index}"
      bootstrap_ip = try(
        var.controlplane_bootstrap_ips[index],
        null,
      )
      hostname = "talos-cp-${index + 1}"
      mac      = format("%s:%02X", var.controlplane_mac_prefix, index)
    }
  }

  worker_nodes = {
    for index in range(var.worker_count) : "talos-worker-${index + 1}" => {
      vmid = var.worker_vmid_start + index
      ip   = "${local.node_network_prefix}.${var.worker_vmid_start + index}"
      bootstrap_ip = try(
        var.worker_bootstrap_ips[index],
        null,
      )
      hostname = "talos-worker-${index + 1}"
      mac      = format("%s:%02X", var.worker_mac_prefix, index)
    }
  }

  # Primeiro control plane, usado para bootstrap/kubeconfig (acoes que exigem
  # um node especifico, nao o VIP). Calculado direto do vmid_start em vez de
  # indexar o map, que nao tem ordem garantida.
  controlplane_ip = coalesce(var.controlplane_ip, "${local.node_network_prefix}.${var.controlplane_vmid_start}")
  cluster_endpoint = coalesce(
    var.cluster_endpoint,
    var.controlplane_vip != "" ? "https://${var.controlplane_vip}:6443" : "https://${local.controlplane_ip}:6443",
  )

  proxmox_controlplane_tags = join(";", sort(distinct(concat(var.proxmox_common_tags, var.proxmox_controlplane_tags))))
  proxmox_worker_tags       = join(";", sort(distinct(concat(var.proxmox_common_tags, var.proxmox_worker_tags))))

  talos_image_schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = var.talos_system_extensions
      }
    }
  })

  # Sem isso o kubelet nunca roda com --cloud-provider=external, e o
  # proxmox-cloud-controller-manager nunca consegue escrever spec.providerID
  # no Node. Sem providerID o Karpenter nunca considera um NodeClaim
  # "Registered", entao a consolidacao/expiracao automatica de nodes
  # provisionados por ele nunca dispara (o node fica rodando pra sempre).
  # Precisa estar tanto nos nodes estaticos (control plane/workers) quanto no
  # user-data usado pelo Karpenter para provisionar workers novos.
  external_cloud_provider_patch = yamlencode({
    cluster = {
      externalCloudProvider = {
        enabled = true
      }
    }
  })

  # OAuth client secrets (tskey-client-...) funcionam como auth keys reusaveis
  # automaticamente, resolvendo o problema de uma unica auth key "single use"
  # falhar ao ser compartilhada entre varios nodes - mas exigem "?ephemeral="
  # e "--advertise-tags" explicitos. Uma auth key normal (tskey-auth-...) ja
  # tem tags/reusable definidos na criacao e nao aceita esses parametros extra.
  tailscale_is_oauth_key = startswith(var.tailscale_auth_key, "tskey-client-")
  tailscale_authkey_value = var.tailscale_auth_key != "" ? (
    local.tailscale_is_oauth_key ? "${var.tailscale_auth_key}?ephemeral=${var.tailscale_ephemeral}" : var.tailscale_auth_key
  ) : ""

  cloudflared_environment = compact([
    var.cloudflared_tunnel_token != "" ? "TUNNEL_TOKEN=${var.cloudflared_tunnel_token}" : "",
    var.cloudflared_metrics != "" ? "TUNNEL_METRICS=${var.cloudflared_metrics}" : "",
    var.cloudflared_edge_ip_version != "" ? "TUNNEL_EDGE_IP_VERSION=${var.cloudflared_edge_ip_version}" : "",
  ])

  cloudflared_patch = var.cloudflared_tunnel_token != "" ? yamlencode({
    apiVersion  = "v1alpha1"
    kind        = "ExtensionServiceConfig"
    name        = "cloudflared"
    environment = local.cloudflared_environment
  }) : null

  # Patches de extension service resolvidos por hostname, ja com TS_HOSTNAME
  # interpolado diretamente (sem o truque de escape "$${hostname}" + replace()).
  extension_service_patches_by_hostname = {
    for node in concat(values(local.controlplane_nodes), values(local.worker_nodes)) : node.hostname => compact([
      var.tailscale_auth_key != "" ? yamlencode({
        apiVersion = "v1alpha1"
        kind       = "ExtensionServiceConfig"
        name       = "tailscale"
        environment = compact([
          "TS_AUTHKEY=${local.tailscale_authkey_value}",
          "TS_HOSTNAME=${node.hostname}",
          local.tailscale_is_oauth_key && length(var.tailscale_tags) > 0 ? "TS_EXTRA_ARGS=--advertise-tags=${join(",", var.tailscale_tags)}" : "",
          length(var.tailscale_routes) > 0 ? "TS_ROUTES=${join(",", var.tailscale_routes)}" : "",
          "TS_ACCEPT_DNS=${var.tailscale_accept_dns}",
          "TS_AUTH_ONCE=${var.tailscale_auth_once}",
        ])
      }) : "",
      local.cloudflared_patch != null ? local.cloudflared_patch : "",
    ])
  }

  # Necessario nos nodes que anunciam TS_ROUTES: sem ip_forward=1 o kernel
  # descarta o trafego que o tailscaled tentaria rotear para a LAN.
  ip_forward_sysctls = length(var.tailscale_routes) > 0 ? {
    "net.ipv4.ip_forward" = "1"
  } : {}

  # Em redes sem IPv6 real (so rota/endereco parcial via RA, sem saida de
  # fato), o containerd tenta a resposta AAAA de registries dual-stack
  # (registry.k8s.io, *.pkg.dev) antes de cair para IPv4, e essa tentativa
  # trava ate estourar o timeout do TLS handshake em vez de falhar rapido -
  # isso multiplica o tempo de cada pull de imagem e pode nunca completar
  # dentro do timeout do bootstrap. Desabilitar IPv6 no kernel evita que o
  # node sequer tente essa rota.
  ipv6_disable_sysctls = var.talos_disable_ipv6 ? {
    "net.ipv6.conf.all.disable_ipv6"     = "1"
    "net.ipv6.conf.default.disable_ipv6" = "1"
  } : {}

  machine_sysctls = merge(local.ip_forward_sysctls, local.ipv6_disable_sysctls)

  machine_sysctls_patch = length(local.machine_sysctls) > 0 ? {
    sysctls = local.machine_sysctls
  } : {}

  # Sem isso, o Talos pode registrar o node no Kubernetes com o IP de outra
  # interface (ex.: tailscale0) em vez do IP da LAN, fazendo trafego interno
  # do cluster (kubelet<->apiserver, kubectl exec/logs) depender de uma VPN
  # que nao tem nada a ver com a rede fisica do cluster.
  lan_cidr = "${local.node_network_prefix}.0/${var.network_prefix_length}"

  # O proxmox-cloud-controller-manager (nesta versao) nao descobre o
  # providerID sozinho via hostname - ele espera que o proprio kubelet se
  # autodeclare com --provider-id (permitido pelo admission NodeRestriction).
  # Formato "proxmox://<regiao>/<vmid>" confirmado observando o providerID
  # que o Karpenter atribui aos nodes que ele mesmo provisiona.
  kubelet_machine_config = {
    for hostname, node in merge(local.controlplane_nodes, local.worker_nodes) : hostname => {
      kubelet = {
        nodeIP = {
          validSubnets = [local.lan_cidr]
        }
        extraArgs = {
          "provider-id" = "proxmox://${var.proxmox_region}/${node.vmid}"
        }
      }
    }
  }

  controlplane_machine_patches = {
    for hostname, node in local.controlplane_nodes : hostname => yamlencode({
      machine = merge(
        {
          network = {
            nameservers = var.network_nameservers
            interfaces = [merge(
              {
                interface = var.talos_network_interface
                dhcp      = false
                addresses = ["${node.ip}/${var.network_prefix_length}"]
                mtu       = var.talos_network_mtu
                routes = [{
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }]
              },
              var.controlplane_vip != "" ? { vip = { ip = var.controlplane_vip } } : {},
            )]
          }
        },
        local.kubelet_machine_config[hostname],
        local.machine_sysctls_patch,
      )
    })
  }

  worker_machine_patches = {
    for hostname, node in local.worker_nodes : hostname => yamlencode({
      machine = merge(
        {
          network = {
            nameservers = var.network_nameservers
            interfaces = [{
              interface = var.talos_network_interface
              dhcp      = false
              addresses = ["${node.ip}/${var.network_prefix_length}"]
              mtu       = var.talos_network_mtu
              routes = [{
                network = "0.0.0.0/0"
                gateway = var.network_gateway
              }]
            }]
          }
        },
        local.kubelet_machine_config[hostname],
        local.machine_sysctls_patch,
      )
    })
  }
}
