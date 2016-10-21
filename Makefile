setup:
	bin/setup

terraform-plan:
	terraform plan -var-file config.tfvars -var-file secrets.tfvars

terraform-apply:
	bin/generate_discovery_url.sh
	terraform apply -var-file config.tfvars -var-file secrets.tfvars

terraform-destroy:
	terraform destroy -var-file config.tfvars -var-file secrets.tfvars
