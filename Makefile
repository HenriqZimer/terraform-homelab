.PHONY: apply destroy plan validate format init

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

deploy: init validate plan apply