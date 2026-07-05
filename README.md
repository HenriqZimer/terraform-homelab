# terraform-homelab

Provisiona VMs Talos no Proxmox e faz o bootstrap de um cluster Kubernetes.

## Talos system extensions

As extensions do Talos são definidas em `talos_system_extensions` e usadas para criar um schematic no Talos Image Factory. Por padrão, o projeto inclui:

- `siderolabs/tailscale`
- `siderolabs/cloudflared`
- `siderolabs/qemu-guest-agent`

O output `talos_image_factory_urls` mostra as URLs dos artefatos gerados. Use a imagem gerada para criar ou atualizar o template do Proxmox definido em `clone_template`; depois disso, as novas VMs clonadas já sobem com as extensions disponíveis.

Observação: `agent = 1` no recurso Proxmox apenas habilita o canal do QEMU Guest Agent na VM. O serviço dentro do Talos vem da extension `qemu-guest-agent`.

Para confirmar que uma VM foi criada a partir do template correto:

```bash
terraform output talos_image_factory_schematic_id
make talos-extensions NODE=192.168.1.200
make talos-services NODE=192.168.1.200
```

O schematic mostrado pelo Talos precisa bater com o output do Terraform, e `make talos-extensions` precisa listar `tailscale`, `cloudflared` e `qemu-guest-agent`. Se aparecer apenas `qemu-guest-agent`, o template Proxmox ainda está usando uma imagem antiga. Nesse caso, recrie ou atualize o template `clone_template` com a URL `disk_image` atual de `terraform output -json talos_image_factory_urls`, depois recrie as VMs.

Para atualizar nodes existentes sem recriar VM, use o installer do Image Factory:

```bash
make talos-upgrade-node NODE=192.168.1.210
make talos-upgrade-node NODE=192.168.1.211
make talos-upgrade-node NODE=192.168.1.200
```

Atualize um node por vez. Em cluster single-control-plane, deixe o control plane por ultimo.

## Tokens

`tailscale_auth_key` e `cloudflared_tunnel_token` são variáveis sensíveis. Você pode defini-las no `terraform.tfvars`, mas o caminho mais limpo é via ambiente:

```bash
export TF_VAR_tailscale_auth_key="tskey-auth-..."
export TF_VAR_cloudflared_tunnel_token="..."
```

Mesmo marcadas como sensíveis, essas credenciais podem acabar no state Terraform porque viram parte da machine config aplicada pelo provider. Guarde o state como segredo.

Para o Tailscale, use uma auth key nova, reutilizável se for aplicar em mais de um node, e preferencialmente ephemeral/pre-authorized para homelab. Se `make talos-tailscale-logs NODE=...` mostrar `invalid key`, a extension está instalada corretamente, mas a key foi revogada, expirou ou já foi consumida.

Depois de trocar a key:

```bash
terraform apply
make talos-tailscale-logs NODE=192.168.1.200
make talos-services NODE=192.168.1.200
```

## Rede e IDs

O prefixo de rede vem dos tres primeiros octetos de `network_gateway`, ou de `node_network_prefix` se você quiser sobrescrever. O último octeto do IP de cada node é o próprio VMID calculado:

- `controlplane_vmid_start = 200` gera `192.168.1.200`
- `worker_vmid_start = 210` gera `192.168.1.210`

As configs Talos agora recebem patch de rede estática usando `network_gateway`, `network_prefix_length`, `network_nameservers` e `talos_network_interface`.

As VMs do Proxmox recebem tags via `proxmox_common_tags`, `proxmox_controlplane_tags` e `proxmox_worker_tags`. Por padrão:

- control planes: `k8s;talos-os;control-plane`
- workers: `k8s;talos-os;worker`

Os workers também recebem o label Kubernetes `node-role.kubernetes.io/worker=""` via `kubernetes_worker_labels`, para aparecerem com role `worker` em `kubectl get nodes`. Esse label é aplicado com `kubectl` após o bootstrap, porque o NodeRestriction do Kubernetes impede que o próprio kubelet do worker configure labels `node-role.kubernetes.io/*`.

`controlplane_ip` e `cluster_endpoint` são opcionais. Se não forem definidos, o Terraform calcula:

```hcl
controlplane_ip  = "<prefixo>.<controlplane_vmid_start>"
cluster_endpoint = "https://<controlplane_ip>:6443"
```

Os mesmos IPs também são enviados ao Proxmox via `ipconfig0` com `vm_os_type = "cloud-init"`. O Terraform anexa um disco Cloud-Init/NoCloud em `ide2`, usando `vm_cloudinit_storage`, para entregar esse seed ao Talos no primeiro boot.

Para isso funcionar no boot inicial, o template Talos precisa ter sido criado a partir de uma imagem Talos `nocloud`; se o template veio de uma imagem `metal`, o Talos ignora o seed cloud-init do Proxmox e vai continuar pegando DHCP.

Com o seed NoCloud funcionando, o caminho normal não precisa de `worker_bootstrap_ips`: os workers já devem subir diretamente em `192.168.1.210`, `192.168.1.211`, etc.

Se você já tem VMs antigas criadas sem o disco Cloud-Init ou fora do state, apague/importe essas VMs antes de rodar `apply` de novo. Caso contrário, o Proxmox pode retornar erros como `VM 210 already running`.

`worker_bootstrap_ips` continua existindo apenas como fallback temporário para templates antigos que ainda sobem por DHCP, por exemplo:

```hcl
worker_bootstrap_ips = ["192.168.1.83", "192.168.1.84"]
```

Esses IPs sao usados apenas para conectar no primeiro apply Talos; a machine config aplicada continua configurando os workers como `192.168.1.210`, `192.168.1.211`, etc.
