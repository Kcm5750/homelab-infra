# Quality gates only. There are deliberately NO plan/apply/destroy targets and
# nothing here runs ansible-playbook: those are run by hand, on purpose.
#
# Requires on PATH: terraform, tflint, ansible-lint, ansible-galaxy, yamllint,
# shellcheck, pre-commit. See README.md ("Running the checks").

TF_DIRS := terraform/environments/staging

.DEFAULT_GOAL := help
.PHONY: help check fmt fmt-check validate tflint yamllint ansible-deps ansible-lint shellcheck pre-commit lint

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

check: fmt-check validate lint ## Run every check (read-only)

fmt: ## Format Terraform files in place
	terraform fmt -recursive terraform

fmt-check: ## Fail if Terraform files are not formatted
	terraform fmt -recursive -check -diff terraform

validate: ## terraform init -backend=false + validate (no state, no server contact)
	@for d in $(TF_DIRS); do \
	  echo "== validate $$d"; \
	  (cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; \
	done

tflint: ## Lint Terraform
	tflint --config=$(CURDIR)/.tflint.hcl --init
	tflint --config=$(CURDIR)/.tflint.hcl --recursive

yamllint: ## Lint all YAML (strict)
	yamllint --strict -c .yamllint.yaml .

ansible-deps: ## Install Ansible collections into ansible/.collections
	cd ansible && ansible-galaxy collection install -r requirements.yml -p .collections

ansible-lint: ansible-deps ## Lint playbooks and roles (production profile)
	cd ansible && ansible-lint --project-dir .

shellcheck: ## Lint shell scripts
	shellcheck scripts/*.sh

pre-commit: ## Run all pre-commit hooks on all files
	pre-commit run --all-files

lint: tflint yamllint ansible-lint shellcheck ## All linters
