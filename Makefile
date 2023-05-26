ifndef PROJECT_ID
	$(error PROJECT_ID is not set)
endif

GCS_TF_STATE_NAME=${PROJECT_ID}-kubernetes-state

.PHONY: deploy \
	configure \
	plan \
	deploy \
	destroy

.SILENT: 
	@

all:

configure:
	@echo "Starting configuration..."
	sed -i -e "s/##PROJECT_ID##/${PROJECT_ID}/g" terraform.tfvars
	sed -i -e "s/##PROJECT_ID##/${PROJECT_ID}/g" terraform.tf
	
	@echo "PROJECT_ID = ${PROJECT_ID}"
	@echo "Configuration successfuly completed."

init:
	@echo "Starting Init..."
	terraform init
	@echo "Initialization successfuly completed"

plan: init
	@echo "Starting planning..."
	terraform plan
	@echo "Planning successfuly completed"

build: init plan
	@echo "Starting Deployment..."
	terraform apply -auto-approve
	@echo "Deployment successfuly completed"

gcs:
	gsutil mb gs://${GCS_TF_STATE_NAME}

destroy: plan
	@echo "Destroing the cloud..."
	terraform destroy --auto-approve
	@echo "Destroyed successfuly"