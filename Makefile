SHELL := /bin/sh
.DEFAULT_GOAL := help

PYTHON ?= python3
VENV ?= .venv
VENV_BIN := $(VENV)/bin
PIP := $(VENV_BIN)/pip
PRE_COMMIT := $(VENV_BIN)/pre-commit
YAMLLINT := $(VENV_BIN)/yamllint
ANSIBLE_LINT := $(VENV_BIN)/ansible-lint
ANSIBLE_PLAYBOOK := $(VENV_BIN)/ansible-playbook
MOLECULE := $(VENV_BIN)/molecule

INVENTORY ?= examples/inventory.yml
LIMIT ?= ghes-primary
UPGRADE_PLAYBOOK ?= examples/upgrade.yml
SERVICE_PLAYBOOK ?= examples/services.yml
SCENARIO ?= default
SERVICE_URL ?=
SERVICE_RESTART_COMMAND ?=
DIST_DIR ?= dist
ARCHIVE_NAME ?= ansible-role-ghes-maintenance.tar.gz

.PHONY: help setup deps hooks check-tools \
	lint lint-yaml lint-ansible syntax pre-commit \
	test molecule molecule-default molecule-guardrails molecule-ha \
	molecule-create molecule-converge molecule-idempotence molecule-verify molecule-destroy molecule-reset \
	upgrade-check upgrade service-status restart-core-services \
	package clean clean-cache clean-molecule clean-dist

help: ## Show this help output
	@printf '\n%s\n\n' 'ansible-role-ghes-maintenance development and operations targets'
	@awk 'BEGIN {FS = ":.*## "; printf "Usage:\n  make %-24s %s\n\nTargets:\n", "<target>", "[VARIABLE=value ...]"} /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-28s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\nCommon overrides:\n'
	@printf '  %-28s %s\n' 'INVENTORY=<path>' 'Ansible inventory file'
	@printf '  %-28s %s\n' 'LIMIT=<host-or-group>' 'Inventory host/group limit'
	@printf '  %-28s %s\n' 'SCENARIO=<name>' 'Molecule scenario (default: default)'
	@printf '  %-28s %s\n' 'SERVICE_URL=<url>' 'Optional post-restart health-check URL'
	@printf '  %-28s %s\n' 'SERVICE_RESTART_COMMAND=<cmd>' 'GitHub Support-approved service restart command'
	@printf '  %-28s %s\n' 'VENV=<path>' 'Python virtual environment directory'
	@printf '\nExamples:\n'
	@printf '  make setup\n'
	@printf '  make test\n'
	@printf '  make molecule-converge SCENARIO=default\n'
	@printf '  make upgrade-check INVENTORY=inventory/prod.yml LIMIT=ghes-primary\n'
	@printf '  make restart-core-services INVENTORY=inventory/prod.yml LIMIT=ghes-primary SERVICE_URL=https://github.example.com\n\n'

setup: deps hooks ## Create the virtual environment, install dependencies, and install Git hooks

deps: $(VENV)/.installed ## Install development dependencies into the virtual environment

$(VENV)/.installed: requirements-dev.txt
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip setuptools wheel
	$(PIP) install -r requirements-dev.txt
	@touch $@

hooks: deps ## Install pre-commit and pre-push hooks
	$(PRE_COMMIT) install --install-hooks
	$(PRE_COMMIT) install --hook-type pre-push

check-tools: deps ## Verify required local development tools are available
	@$(ANSIBLE_PLAYBOOK) --version >/dev/null
	@$(ANSIBLE_LINT) --version >/dev/null
	@$(MOLECULE) --version >/dev/null
	@$(PRE_COMMIT) --version >/dev/null
	@printf '%s\n' 'Required development tools are available.'

lint: lint-yaml lint-ansible ## Run all static analysis checks

lint-yaml: deps ## Run yamllint against repository YAML files
	$(YAMLLINT) .

lint-ansible: deps ## Run ansible-lint against the role and examples
	$(ANSIBLE_LINT)

syntax: deps ## Run Ansible syntax checks for example playbooks
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(UPGRADE_PLAYBOOK) --syntax-check
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) examples/upgrade_ha.yml --syntax-check
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(SERVICE_PLAYBOOK) --syntax-check

pre-commit: deps ## Run every configured pre-commit hook against all files
	PATH="$(abspath $(VENV_BIN)):$$PATH" $(PRE_COMMIT) run --all-files --show-diff-on-failure

test: lint syntax molecule ## Run static analysis, syntax checks, and all Molecule scenarios

molecule: molecule-default molecule-guardrails molecule-ha ## Run all Molecule scenarios

molecule-default: deps ## Run the successful mocked GHES upgrade scenario
	$(MOLECULE) test -s default

molecule-guardrails: deps ## Run unsafe-input and unsupported-topology guardrail tests
	$(MOLECULE) test -s guardrails

molecule-ha: deps ## Run the three-node mocked HA upgrade scenario
	$(MOLECULE) test -s ha

molecule-create: deps ## Create the selected Molecule scenario resources
	$(MOLECULE) create -s $(SCENARIO)

molecule-converge: deps ## Converge the selected Molecule scenario
	$(MOLECULE) converge -s $(SCENARIO)

molecule-idempotence: deps ## Run idempotence for the selected Molecule scenario when supported
	$(MOLECULE) idempotence -s $(SCENARIO)

molecule-verify: deps ## Verify the selected Molecule scenario
	$(MOLECULE) verify -s $(SCENARIO)

molecule-destroy: deps ## Destroy the selected Molecule scenario resources
	$(MOLECULE) destroy -s $(SCENARIO)

molecule-reset: molecule-destroy molecule-create molecule-converge ## Rebuild and converge the selected Molecule scenario

upgrade-check: deps ## Run the GHES upgrade playbook in Ansible check mode
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(UPGRADE_PLAYBOOK) \
		--limit '$(LIMIT)' \
		--check --diff

upgrade: deps ## Run the guarded GHES upgrade playbook; required upgrade variables must be supplied
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(UPGRADE_PLAYBOOK) \
		--limit '$(LIMIT)'

service-status: deps ## Display GHES core-service status for the selected instance
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(SERVICE_PLAYBOOK) \
		--limit '$(LIMIT)' \
		-e service_action=status

restart-core-services: deps ## Guardedly reload/restart GHES core services and run sanity checks
	@test -n "$(SERVICE_RESTART_COMMAND)" || { \
		printf '%s\n' 'Set SERVICE_RESTART_COMMAND to a GitHub Support-approved command.'; \
		exit 2; \
	}
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(SERVICE_PLAYBOOK) \
		--limit '$(LIMIT)' \
		-e service_action=restart_core \
		-e service_restart_confirm=true \
		-e service_restart_command='$(SERVICE_RESTART_COMMAND)' \
		$(if $(SERVICE_URL),-e service_external_url='$(SERVICE_URL)',)

package: clean-dist ## Create a distributable repository archive under DIST_DIR
	@mkdir -p $(DIST_DIR)
	tar \
		--exclude='./$(VENV)' \
		--exclude='./$(DIST_DIR)' \
		--exclude='./.git' \
		--exclude='./.ansible' \
		--exclude='./.molecule' \
		--exclude='./__pycache__' \
		-czf $(DIST_DIR)/$(ARCHIVE_NAME) .
	@printf 'Created %s\n' '$(DIST_DIR)/$(ARCHIVE_NAME)'

clean: clean-cache clean-molecule clean-dist ## Remove generated caches, Molecule state, and distribution files

clean-cache: ## Remove Python, Ansible, lint, and test caches
	find . -type d \( -name '__pycache__' -o -name '.pytest_cache' -o -name '.mypy_cache' -o -name '.ruff_cache' \) -prune -exec rm -rf {} +
	find . -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.retry' \) -delete
	rm -rf .cache .ansible .coverage htmlcov coverage.xml junit.xml

clean-molecule: ## Destroy Molecule scenarios and remove local Molecule state
	@if [ -x "$(MOLECULE)" ]; then \
		$(MOLECULE) destroy -s default || true; \
		$(MOLECULE) destroy -s guardrails || true; \
		$(MOLECULE) destroy -s ha || true; \
	fi
	rm -rf .molecule

clean-dist: ## Remove generated distribution archives
	rm -rf $(DIST_DIR)
