.PHONY: bootstrap init up down costs fmt validate lint

# 1. Create the state bucket (local state) and write infra/backend.hcl
bootstrap:
	terraform -chdir=bootstrap init
	terraform -chdir=bootstrap apply
	terraform -chdir=bootstrap output -raw backend_hcl > infra/backend.hcl
	@echo "Wrote infra/backend.hcl"

# 2. Connect the lab stack to the remote backend
init:
	terraform -chdir=infra init -backend-config=backend.hcl

# 3. Baseline infrastructure (Setup phase of every scenario)
up:
	terraform -chdir=infra apply

# Cleanup phase: destroy and prove nothing is left running
down:
	terraform -chdir=infra destroy
	./scripts/check-costs.sh

costs:
	./scripts/check-costs.sh

fmt:
	terraform fmt -recursive

validate:
	terraform -chdir=infra validate
	terraform -chdir=bootstrap validate

# Offline checks only: no AWS calls, no backend, no credentials needed.
# Also creates/updates the .terraform.lock.hcl files (commit them).
lint:
	terraform fmt -check -recursive
	terraform -chdir=infra init -backend=false -input=false
	terraform -chdir=infra validate
	terraform -chdir=bootstrap init -backend=false -input=false
	terraform -chdir=bootstrap validate
	shellcheck scripts/*.sh scenarios/*/*.sh
