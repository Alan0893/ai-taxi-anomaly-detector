# AI Taxi Anomaly Detector - Makefile
# Simplifies OpenShift project and Helm chart lifecycle management.

NAMESPACE ?= ai-taxi-anomaly-detector
RELEASE_NAME ?= ai-taxi-anomaly-detector
CHART_DIR ?= chart
TIMEOUT ?= 15m
ODS_NAMESPACE ?= redhat-ods-applications
OPENSHIFT_USER ?= $(shell oc whoami 2>/dev/null)
DASHBOARD_HOST ?= $(shell oc get route rhods-dashboard -n $(ODS_NAMESPACE) -o jsonpath='{.spec.host}' 2>/dev/null)

.PHONY: help create-project install uninstall delete-project

help: ## Display available targets
	@echo "AI Taxi Anomaly Detector - Makefile"
	@echo "==================================="
	@echo ""
	@echo "Configuration:"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  RELEASE_NAME=$(RELEASE_NAME)"
	@echo "  CHART_DIR=$(CHART_DIR)"
	@echo "  OPENSHIFT_USER=$(OPENSHIFT_USER)"
	@echo "  DASHBOARD_HOST=$(DASHBOARD_HOST)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

create-project: ## Create an OpenShift project (oc new-project)
	@echo "Creating OpenShift project: $(NAMESPACE)"
	@oc new-project $(NAMESPACE) || echo "Project $(NAMESPACE) already exists"

install: ## Install the ai-taxi-anomaly-detector Helm chart
	@if [ -z "$(OPENSHIFT_USER)" ]; then echo "ERROR: OPENSHIFT_USER is empty. Log in with oc and retry, or pass OPENSHIFT_USER=<your-user>."; exit 1; fi
	@if [ -z "$(DASHBOARD_HOST)" ]; then echo "ERROR: DASHBOARD_HOST is empty. Ensure OpenShift AI is installed and rhods-dashboard route exists."; exit 1; fi
	@echo "Updating Helm chart dependencies..."
	@helm dependency update $(CHART_DIR)
	@echo "Installing $(RELEASE_NAME) in project $(NAMESPACE)..."
	@echo "  notebook.username=$(OPENSHIFT_USER)"
	@echo "  notebook.dashboard.host=$(DASHBOARD_HOST)"
	@helm upgrade --install $(RELEASE_NAME) $(CHART_DIR) \
		--namespace $(NAMESPACE) \
		--set notebook.username="$(OPENSHIFT_USER)" \
		--set notebook.dashboard.host="$(DASHBOARD_HOST)" \
		--wait \
		--timeout $(TIMEOUT)
	@echo "Installation complete."

uninstall: ## Uninstall the ai-taxi-anomaly-detector Helm chart
	@echo "Uninstalling $(RELEASE_NAME) from project $(NAMESPACE)..."
	@helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) 2>/dev/null || echo "Release $(RELEASE_NAME) not found"
	@echo "Uninstall complete."

delete-project: ## Delete the OpenShift project
	@echo "Deleting OpenShift project: $(NAMESPACE)"
	@oc delete project $(NAMESPACE) 2>/dev/null || echo "Project $(NAMESPACE) not found"
	@echo "Project deletion initiated."
