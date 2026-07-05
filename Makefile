NODE ?= 192.168.1.200
TALOSCONFIG ?= ./configs/talosconfig
KUBECONFIG ?= ./configs/kubeconfig
TALOS_UPGRADE_IMAGE ?= $(shell terraform output -json talos_image_factory_urls 2>/dev/null | jq -r .installer)

.PHONY: apply destroy plan validate format init deploy merge-talosconfig merge-kubeconfig talos-extensions talos-services talos-tailscale-logs talos-cloudflared-logs talos-upgrade-node

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

plan:
	terraform plan

validate:
	terraform validate

format:
	terraform fmt -recursive

init:
	terraform init

deploy: init validate plan apply merge-talosconfig merge-kubeconfig

merge-talosconfig:
	talosctl config merge $(TALOSCONFIG)

merge-kubeconfig:
	talosctl kubeconfig ~/.kube/config --talosconfig $(TALOSCONFIG) --nodes $(NODE) --merge=true --force

talos-extensions:
	talosctl --talosconfig $(TALOSCONFIG) --nodes $(NODE) get extensions

talos-services:
	talosctl --talosconfig $(TALOSCONFIG) --nodes $(NODE) services | grep -E 'tailscale|cloudflared|qemu|ext-' || true

talos-tailscale-logs:
	talosctl --talosconfig $(TALOSCONFIG) --nodes $(NODE) logs ext-tailscale

talos-cloudflared-logs:
	talosctl --talosconfig $(TALOSCONFIG) --nodes $(NODE) logs ext-cloudflared

talos-upgrade-node:
	test -n "$(TALOS_UPGRADE_IMAGE)"
	talosctl --talosconfig $(TALOSCONFIG) --nodes $(NODE) upgrade --image $(TALOS_UPGRADE_IMAGE) --wait --timeout=30m --progress=plain
