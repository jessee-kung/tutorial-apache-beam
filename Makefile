export MKFILE     := $(realpath $(lastword $(MAKEFILE_LIST)))
export MKFILE_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

DEPENDENCIES = terraform jq mvn gcloud
$(foreach exec,$(DEPENDENCIES), $(if $(shell which $(exec)),,$(error "No $(exec) installation found. Please install and try again")))

.PHONY: deploy-infra
deploy-infra:
	cd ${MKFILE_DIR}/deployment/environments/dev/infra; terraform init; terraform validate; terraform apply

.PHONY: destroy-infra
destroy-infra:
	cd ${MKFILE_DIR}/deployment/environments/dev/infra; terraform init; terraform destroy

.PHONY: direct-runner
direct-runner:
	./template_helper.sh direct-run ${TOPIC}

.PHONY: build-template
build-template:
	./template_helper.sh build ${TOPIC}

.PHONY: deploy-job
deploy-job:
	./template_helper.sh run ${TOPIC}

.PHONY: destroy-job
destroy-job:

help:
	@printf "\033[32mMakefile for build and deployment Beam Tutorial pipelines\033[0m\n\n"
	
	@echo "To create or destroy Pub/Sub Lite and BigQuery resources in Google Cloud platform, use:"
	@echo "    make deploy-infra"
	@echo "    make destroy-infra"
	@echo ""
	@echo "To run Apache Beam pipelines with direct runner, use:"
	@echo "    make direct-runner  TOPIC=[demo1|demo2]"
	@echo ""
	@echo "To deploy Apache Beam pipelines with Google Dataflow Runners, use:"
	@echo "    make build-template TOPIC=[demo1|demo2]"
	@echo "    make deploy-job     TOPIC=[demo1|demo2]"
	@echo "    make destroy-job    TOPIC=[demo1|demo2]"
	
.DEFAULT_GOAL := help