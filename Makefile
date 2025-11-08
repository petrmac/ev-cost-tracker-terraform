.PHONY: help init plan-dev plan-prod apply-dev apply-prod destroy-dev destroy-prod fmt validate

help:
	@echo "Available commands:"
	@echo "  make init          - Initialize Terraform"
	@echo "  make plan-dev      - Plan changes for dev environment"
	@echo "  make plan-prod     - Plan changes for prod environment"
	@echo "  make apply-dev     - Apply changes to dev environment"
	@echo "  make apply-prod    - Apply changes to prod environment"
	@echo "  make destroy-dev   - Destroy dev environment"
	@echo "  make destroy-prod  - Destroy prod environment"
	@echo "  make fmt           - Format Terraform files"
	@echo "  make validate      - Validate Terraform configuration"

init:
	terraform init

plan-dev:
	terraform workspace select dev || terraform workspace new dev
	terraform plan -var-file=environments/dev/terraform.tfvars -var-file=secrets.tfvars

plan-prod:
	terraform workspace select prod || terraform workspace new prod
	terraform plan -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars

apply-dev:
	terraform workspace select dev || terraform workspace new dev
	terraform apply -var-file=environments/dev/terraform.tfvars -var-file=secrets.tfvars

apply-prod:
	terraform workspace select prod || terraform workspace new prod
	terraform apply -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars

destroy-dev:
	terraform workspace select dev
	terraform destroy -var-file=environments/dev/terraform.tfvars -var-file=secrets.tfvars

destroy-prod:
	terraform workspace select prod
	terraform destroy -var-file=environments/prod/terraform.tfvars -var-file=secrets.tfvars

fmt:
	terraform fmt -recursive

validate:
	terraform validate