# Simple automation for building the Docker image and applying Terraform.
# Usage:
#   make deploy   # full flow

# Directory containing Dockerfile (repo root)
IMAGE_DIR ?= .

# Directory holding Terraform configuration
TERRAFORM_DIR ?= cloud-engineer-agent-terraform
REGION    ?= $(shell terraform -chdir=$(TERRAFORM_DIR) output -raw aws_region 2>/dev/null || echo "us-east-1")
REPO_URI  = $(shell terraform -chdir=$(TERRAFORM_DIR) output -raw agent_repo_uri 2>/dev/null || echo "")

.PHONY: init apply build push deploy force-new

init:
	terraform -chdir=$(TERRAFORM_DIR) init -upgrade

apply:
	terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve

build:
	@if [ -z "$(REPO_URI)" ]; then \
		echo "Repository URI not found. Did you run 'make apply'?"; exit 1; \
	fi
	docker build -t $(REPO_URI):latest $(IMAGE_DIR)

push:
	@if [ -z "$(REPO_URI)" ]; then \
		echo "Repository URI not found. Did you run 'make apply'?"; exit 1; \
	fi
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(shell echo $(REPO_URI) | cut -d'/' -f1)
	docker push $(REPO_URI):latest

# Optional: force the ECS service to pull the new image digest
force-new:
	aws ecs update-service --cluster $(shell terraform -chdir=$(TERRAFORM_DIR) output -raw cloud_engineer_agent_cluster_id 2>/dev/null || echo "") \
		--service $(shell terraform -chdir=$(TERRAFORM_DIR) output -raw cloud_engineer_agent_service_name 2>/dev/null || echo "") \
		--force-new-deployment

deploy: init apply build push apply
	@echo "Deployment complete. Access the agent at: $$(terraform -chdir=$(TERRAFORM_DIR) output -raw agent_url)"
