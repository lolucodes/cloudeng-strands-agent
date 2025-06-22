# Makefile to build & push Docker image then apply Terraform

# Directory containing Dockerfile
IMAGE_DIR ?= ..

# AWS region; fall back to us-east-1 if var not set and terraform output unavailable yet
REGION ?= $(shell terraform -chdir=$(CURDIR) output -raw aws_region 2>/dev/null || echo "us-east-1")

# ECR repo URI, filled after initial terraform apply
REPO_URI = $(shell terraform -chdir=$(CURDIR) output -raw agent_repo_uri 2>/dev/null || echo "")

.PHONY: init validate plan apply docker-build docker-push deploy destroy

init:
	terraform -chdir=$(CURDIR) init -upgrade

validate:
	terraform -chdir=$(CURDIR) validate

plan:
	terraform -chdir=$(CURDIR) plan

apply:
	terraform -chdir=$(CURDIR) apply -auto-approve

docker-build:
	@if [ -z "$(REPO_URI)" ]; then echo "Run 'make apply' first to create the ECR repo and obtain its URI."; exit 1; fi
	docker build -t $(REPO_URI):latest $(IMAGE_DIR)

docker-push:
	@if [ -z "$(REPO_URI)" ]; then echo "Run 'make apply' first to create the ECR repo and obtain its URI."; exit 1; fi
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(shell echo $(REPO_URI) | cut -d'/' -f1)
	docker push $(REPO_URI):latest

# Full flow: initialise, deploy infrastructure, build & push image, redeploy to pick up new image

deploy: init apply docker-build docker-push apply
	@echo "Deployment complete. Visit: $$(terraform -chdir=$(CURDIR) output -raw agent_url)"

destroy:
	terraform -chdir=$(CURDIR) destroy -auto-approve
