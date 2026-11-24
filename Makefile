SHELL := /usr/bin/env bash

VENV ?= $(CURDIR)/.venv
PYTHON ?= python3
ANSIBLE_PLAYBOOK ?= $(VENV)/bin/ansible-playbook
ANSIBLE_GALAXY ?= $(VENV)/bin/ansible-galaxy
ANSIBLE_LINT ?= $(VENV)/bin/ansible-lint
YAMLLINT ?= $(VENV)/bin/yamllint
MOLECULE ?= $(VENV)/bin/molecule
INVENTORY ?= inventories/dev/hosts.yml
COLLECTIONS := $(CURDIR)/collections
REBOOT ?= false

export ANSIBLE_CONFIG := $(CURDIR)/ansible.cfg
export ANSIBLE_COLLECTIONS_PATH := $(COLLECTIONS)
export PATH := $(VENV)/bin:$(PATH)

.PHONY: help deps lint syntax test-image molecule dev-up dev-down deploy-dev-check deploy-dev verify check-prod deploy-prod verify-prod update-prod init-prod integration secrets-dev test clean

help:
	@echo "Technitium DNS/DHCP host targets:"
	@echo "  make deps               Create the venv and install pinned dependencies"
	@echo "  make lint               yamllint, ansible-lint, and policy checks"
	@echo "  make syntax             Syntax-check all playbooks"
	@echo "  make test-image         Build the AlmaLinux 10 systemd test image"
	@echo "  make molecule           Run all Molecule scenarios (requires Docker)"
	@echo "  make dev-up             Start the development container"
	@echo "  make dev-down           Stop the development container"
	@echo "  make secrets-dev        Create the encrypted development secrets file"
	@echo "  make deploy-dev-check   Check mode against development"
	@echo "  make deploy-dev         Apply to development"
	@echo "  make verify             Verify development"
	@echo "  make integration        Full apply and test-only DHCP proof"
	@echo "  make init-prod          Generate a private production inventory"
	@echo "  make check-prod         Check mode against PROD_INVENTORY"
	@echo "  make deploy-prod        Apply to PROD_INVENTORY"
	@echo "  make verify-prod        Verify PROD_INVENTORY"
	@echo "  make update-prod        Apply security updates and converge (REBOOT=true optional)"
	@echo "  make test               lint, syntax, and Molecule"

$(VENV)/bin/ansible:
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements-dev.txt

deps: $(VENV)/bin/ansible
	$(ANSIBLE_GALAXY) collection install -r requirements.yml -p ./collections --force

lint: deps
	$(YAMLLINT) .
	$(ANSIBLE_LINT)
	./scripts/check-policy.sh

syntax: deps
	@for playbook in site.yml playbooks/*.yml playbooks/tests/*.yml; do \
		echo "Checking $$playbook"; \
		$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) "$$playbook" --syntax-check; \
	done

test-image:
	docker build -t technitium-host/almalinux10-ansible:10 docker/dev

molecule: test-image
	@set -e; \
	for role in common podman technitium nginx; do \
		echo "== Molecule: $$role"; \
		cd "$(CURDIR)/roles/$$role"; \
		$(MOLECULE) test; \
	done

dev-up:
	./scripts/dev-up.sh

dev-down:
	./scripts/dev-down.sh

deploy-dev-check: deps
	$(ANSIBLE_PLAYBOOK) -i inventories/dev/hosts.yml site.yml --check --diff

deploy-dev: deps
	$(ANSIBLE_PLAYBOOK) -i inventories/dev/hosts.yml site.yml

verify: deps
	$(ANSIBLE_PLAYBOOK) -i inventories/dev/hosts.yml playbooks/verify.yml

integration: deps
	ANSIBLE_PLAYBOOK=$(ANSIBLE_PLAYBOOK) ./scripts/integration-test.sh

secrets-dev:
	./scripts/init-secrets.sh dev

PROD_DIR ?= $(HOME)/.config/technitium-ansible/prod

init-prod:
	./scripts/init-prod-inventory.sh "$(PROD_DIR)"

check-prod: deps
	@: $${PROD_INVENTORY:?set PROD_INVENTORY to the private production hosts.yml}
	$(ANSIBLE_PLAYBOOK) -i "$${PROD_INVENTORY}" site.yml --check --diff

deploy-prod: deps
	@: $${PROD_INVENTORY:?set PROD_INVENTORY to the private production hosts.yml}
	$(ANSIBLE_PLAYBOOK) -i "$${PROD_INVENTORY}" site.yml

verify-prod: deps
	@: $${PROD_INVENTORY:?set PROD_INVENTORY to the private production hosts.yml}
	$(ANSIBLE_PLAYBOOK) -i "$${PROD_INVENTORY}" playbooks/verify.yml

update-prod: deps
	@: $${PROD_INVENTORY:?set PROD_INVENTORY to the private production hosts.yml}
	$(ANSIBLE_PLAYBOOK) -i "$${PROD_INVENTORY}" playbooks/update.yml \
		-e update_reboot=$(REBOOT)
	$(ANSIBLE_PLAYBOOK) -i "$${PROD_INVENTORY}" site.yml
	$(ANSIBLE_PLAYBOOK) -i "$${PROD_INVENTORY}" playbooks/verify.yml

test: lint syntax molecule

clean:
	rm -rf .cache .molecule
